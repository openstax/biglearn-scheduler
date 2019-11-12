class Services::FetchCourseEvents::Service < Services::ApplicationService
  BATCH_SIZE = 1000
  GRACE_PERIOD = 1.month

  # create_course is already included in the metadata
  # and would not be useful to look at except for error-checking
  RELEVANT_EVENT_TYPES = [
    :prepare_course_ecosystem,
    :update_course_ecosystem,
    :update_roster,
    :update_course_active_dates,
    :update_globally_excluded_exercises,
    :update_course_excluded_exercises,
    :create_update_assignment,
    :record_response
  ]

  def process(event_types: RELEVANT_EVENT_TYPES, restart: false)
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    co = Course.arel_table
    last_uuid = nil
    course_uuids_to_requery = []
    results = []
    total_events = 0
    total_courses = 0

    # Query events for all courses in chunks
    loop do
      num_courses = Course.transaction do
        # Order needed because we are processing the courses in chunks
        course_relation = Course.ordered.lock('FOR NO KEY UPDATE SKIP LOCKED')
        course_relation = course_relation.where(
          co[:ends_at].gt(start_time - GRACE_PERIOD).or(
            co[:updated_at].gt(start_time - GRACE_PERIOD)
          )
        ) unless restart
        course_relation = course_relation.where(co[:uuid].gt(last_uuid)) unless last_uuid.nil?
        courses = course_relation.take(BATCH_SIZE)
        courses_size = courses.size
        next 0 if courses_size == 0

        last_uuid = courses.last.uuid

        partial_course_uuids_to_requery, partial_results, num_events =
          fetch_and_process_course_events(courses, event_types, restart, start_time)

        course_uuids_to_requery.concat partial_course_uuids_to_requery
        results.concat partial_results
        total_events += num_events

        courses_size
      end

      total_courses += num_courses
      break if num_courses < BATCH_SIZE
    end

    # Re-query events for courses that still had more events available until they are all exhausted
    # This is done so we can catch up with courses emitting a lot of events
    loop do
      Course.transaction do
        courses = Course.where(uuid: course_uuids_to_requery.shift(BATCH_SIZE))
                        .lock('FOR NO KEY UPDATE SKIP LOCKED')
                        .to_a
        next if courses.empty?

        partial_course_uuids_to_requery, partial_results, num_events =
          fetch_and_process_course_events(courses, event_types, restart, start_time)

        course_uuids_to_requery.concat partial_course_uuids_to_requery
        results.concat partial_results
        total_events += num_events
      end

      break if course_uuids_to_requery.empty?
    end

    log(:debug) do
      conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
      time = Time.current - start_time

      "Received: #{total_events} event(s) from #{total_courses} course(s)" +
      " with #{conflicts} conflict(s) in #{time} second(s)"
    end
  end

  protected

  def fetch_and_process_course_events(courses, event_types, restart, current_time)
    ec = ExerciseCalculation.arel_table
    as = Assignment.arel_table
    course_uuids_to_requery = []
    results = []
    total_events = 0

    course_event_requests = []
    courses_by_course_uuid = courses.map do |course|
      course_event_requests << { course: course, event_types: event_types, restart: restart }

      [ course.uuid, course ]
    end.to_h

    course_event_responses = OpenStax::Biglearn::Api
      .fetch_course_events(course_event_requests)
      .values
      .map(&:deep_symbolize_keys)

    ecosystem_preparations = []
    course_uuids_with_changed_ecosystems = []
    course_uuids_with_changed_rosters = []
    book_container_mappings = []
    course_containers_hash = {}
    students_hash = {}
    assignments_hash = {}
    used_algorithm_exercise_calculation_uuids = []
    assigned_exercises = []
    student_uuids_by_assigned_exercise_uuid = Hash.new { |hash, key| hash[key] = [] }
    responses_hash = {}
    courses = course_event_responses.map do |course_event_response|
      events = course_event_response.fetch :events
      num_events = events.size
      next if num_events == 0

      total_events += num_events

      course_uuid = course_event_response.fetch :course_uuid
      course = courses_by_course_uuid.fetch course_uuid

      course_uuids_to_requery << course.uuid \
        unless course_event_response.fetch(:is_gap) || course_event_response.fetch(:is_end)

      limit_sequence_number = [
        course.sequence_number, events.map { |event| event.fetch(:sequence_number) }.max + 1
      ].max

      events_by_type = events.group_by { |event| event.fetch(:event_type) }

      # Prepare course ecosystem is stored for a future update
      # and used as a signal to start precomputing CLUes and PracticeWorstAreas
      prepare_ecosystems = events_by_type['prepare_course_ecosystem'] || []
      book_container_mappings_by_sequence_number = {}
      ecosystem_preparations_by_sequence_number = {}
      prepare_ecosystems.each do |prepare_course_ecosystem|
        data = prepare_course_ecosystem.fetch(:event_data)

        ecosystem_map = data.fetch(:ecosystem_map)

        sequence_number = prepare_course_ecosystem.fetch :sequence_number

        # Forward mappings
        from_ecosystem_uuid = ecosystem_map.fetch(:from_ecosystem_uuid)
        to_ecosystem_uuid = ecosystem_map.fetch(:to_ecosystem_uuid)
        book_container_mappings_by_sequence_number[sequence_number] = \
          ecosystem_map.fetch(:book_container_mappings).map do |mapping|
          BookContainerMapping.new(
            uuid: SecureRandom.uuid,
            from_ecosystem_uuid: from_ecosystem_uuid,
            to_ecosystem_uuid: to_ecosystem_uuid,
            from_book_container_uuid: mapping.fetch(:from_book_container_uuid),
            to_book_container_uuid: mapping.fetch(:to_book_container_uuid)
          )
        end

        ecosystem_preparations_by_sequence_number[sequence_number] = EcosystemPreparation.new(
          uuid: data.fetch(:preparation_uuid),
          course_uuid: data.fetch(:course_uuid),
          ecosystem_uuid: data.fetch(:ecosystem_uuid)
        )
      end

      # Update course ecosystem changes the course ecosystem and is used as a signal
      # to stop computing CLUes and PracticeWorstAreas for the previous ecosystem
      update_ecosystems = events_by_type['update_course_ecosystem'] || []
      last_update_ecosystem = update_ecosystems.last
      if last_update_ecosystem.present?
        preparation_uuid = last_update_ecosystem.fetch(:event_data).fetch(:preparation_uuid)
        # Look in the current updates for the EcosystemPreparation
        # If not found, look in the database
        preparation = ecosystem_preparations_by_sequence_number.values.find do |prep|
          prep.uuid == preparation_uuid
        end
        preparation ||= EcosystemPreparation.find_by uuid: preparation_uuid

        if preparation.nil?
          # Stop right before this event if the preparation was not found
          # We'll retry later and hopefully find the missing preparation or skip over it
          limit_sequence_number = last_update_ecosystem.fetch :sequence_number

          events_by_type.each do |_, events|
            events.reject! { |event| event.fetch(:sequence_number) >= limit_sequence_number }
          end
          book_container_mappings_by_sequence_number.delete_if do |sequence_number, _|
            sequence_number >= limit_sequence_number
          end
          ecosystem_preparations_by_sequence_number.delete_if do |sequence_number, _|
            sequence_number >= limit_sequence_number
          end
        else
          course.ecosystem_uuid = preparation.ecosystem_uuid
          course_uuids_with_changed_ecosystems << course.uuid
        end
      end

      book_container_mappings.concat book_container_mappings_by_sequence_number.values.flatten
      ecosystem_preparations.concat ecosystem_preparations_by_sequence_number.values

      # Update roster changes the students and periods we compute CLUes for
      update_rosters = events_by_type['update_roster'] || []
      last_roster = update_rosters.last
      if last_roster.present?
        data = last_roster.fetch(:event_data)
        containers = data.fetch(:course_containers)
        parent_uuids_by_container_uuid = containers.map do |container|
          [ container.fetch(:container_uuid), container.fetch(:parent_container_uuid) ]
        end.to_h

        student_uuids_by_container_uuid = Hash.new { |hash, key| hash[key] = [] }
        data.fetch(:students).each do |student|
          container_uuids = []
          current_container_uuid = student.fetch(:container_uuid)
          student_uuid = student.fetch(:student_uuid)

          # Flatten the course tree structure into arrays of uuids
          until current_container_uuid.nil? ||
                current_container_uuid == course_uuid ||
                container_uuids.include?(current_container_uuid) do
            container_uuids << current_container_uuid
            student_uuids_by_container_uuid[current_container_uuid] << student_uuid

            current_container_uuid = parent_uuids_by_container_uuid[current_container_uuid]
          end

          students_hash[student_uuid] = Student.new(
            uuid: student_uuid,
            course_uuid: course_uuid,
            course_container_uuids: container_uuids
          )
        end

        containers.each do |course_container|
          container_uuid = course_container.fetch(:container_uuid)

          course_containers_hash[container_uuid] = CourseContainer.new(
            uuid: container_uuid,
            course_uuid: course_uuid,
            student_uuids: student_uuids_by_container_uuid[container_uuid]
          )
        end

        course_uuids_with_changed_rosters << course.uuid
      end

      # Update course active dates is used to exclude past courses from calculations
      update_course_active_dates = events_by_type['update_course_active_dates'] || []
      last_course_active_date_update = update_course_active_dates.last
      if last_course_active_date_update.present?
        course.starts_at = DateTime.iso8601(
          last_course_active_date_update.fetch(:event_data).fetch(:starts_at)
        )
        course.ends_at = DateTime.iso8601(
          last_course_active_date_update.fetch(:event_data).fetch(:ends_at)
        )
      end

      # Update globally excluded exercises and update course excluded exercises
      # mark some exercises as unavailable for PE/SPE/PracticeWorstAreas
      update_global_exclusions = events_by_type['update_globally_excluded_exercises'] || []
      last_global_exclusion_update = update_global_exclusions.last
      if last_global_exclusion_update.present?
        exclusions = last_global_exclusion_update.fetch(:event_data).fetch(:exclusions)

        exercise_uuids = []
        exercise_group_uuids = []
        exclusions.each do |exclusion|
          exercise_uuids << exclusion[:exercise_uuid] unless exclusion[:exercise_uuid].nil?
          exercise_group_uuids << exclusion[:exercise_group_uuid] \
            unless exclusion[:exercise_group_uuid].nil?
        end

        course.global_excluded_exercise_uuids = exercise_uuids
        course.global_excluded_exercise_group_uuids = exercise_group_uuids
      end

      update_course_exclusions = events_by_type['update_course_excluded_exercises'] || []
      last_course_exclusion_update = update_course_exclusions.last
      if last_course_exclusion_update.present?
        exclusions = last_course_exclusion_update.fetch(:event_data).fetch(:exclusions)

        exercise_uuids = []
        exercise_group_uuids = []
        exclusions.each do |exclusion|
          exercise_uuids << exclusion[:exercise_uuid] unless exclusion[:exercise_uuid].nil?
          exercise_group_uuids << exclusion[:exercise_group_uuid] \
            unless exclusion[:exercise_group_uuid].nil?
        end

        course.course_excluded_exercise_uuids = exercise_uuids
        course.course_excluded_exercise_group_uuids = exercise_group_uuids
      end

      # Create update assignment changes the assignments we compute PEs and SPEs for
      create_update_assignments = events_by_type['create_update_assignment'] || []
      create_update_assignments.group_by do |create_update_assignment|
        create_update_assignment.fetch(:event_data).fetch(:assignment_uuid)
      end.each do |assignment_uuid, create_update_assignments|
        last_create_update_assignment = create_update_assignments.last
        data = last_create_update_assignment.fetch(:event_data)

        ecosystem_uuid = data.fetch(:ecosystem_uuid)
        student_uuid = data.fetch(:student_uuid)
        exercises = data.fetch(:assigned_exercises)
        exercise_uuids = exercises.map { |exercise| exercise.fetch(:exercise_uuid) }.uniq

        exclusion_info = data.fetch(:exclusion_info, {})
        opens_at = exclusion_info[:opens_at]
        due_at = exclusion_info[:due_at]
        feedback_at = exclusion_info[:feedback_at]

        pe_calculation_uuid = data.dig(:pes, :calculation_uuid)
        spe_calculation_uuid = data.dig(:spes, :calculation_uuid)

        used_algorithm_exercise_calculation_uuids << pe_calculation_uuid \
          unless pe_calculation_uuid.nil?
        used_algorithm_exercise_calculation_uuids << spe_calculation_uuid \
          unless spe_calculation_uuid.nil?

        assignments_hash[assignment_uuid] = Assignment.new(
          uuid: assignment_uuid,
          course_uuid: course_uuid,
          ecosystem_uuid: ecosystem_uuid,
          student_uuid: student_uuid,
          assignment_type: data.fetch(:assignment_type),
          opens_at: opens_at.nil? ? nil : DateTime.iso8601(opens_at),
          due_at: due_at.nil? ? nil : DateTime.iso8601(due_at),
          feedback_at: feedback_at.nil? ? nil : DateTime.iso8601(feedback_at),
          assigned_book_container_uuids: data.fetch(:assigned_book_container_uuids),
          assigned_exercise_uuids: exercise_uuids,
          goal_num_tutor_assigned_spes: data[:goal_num_tutor_assigned_spes],
          spes_are_assigned: data.fetch(:spes_are_assigned),
          goal_num_tutor_assigned_pes: data[:goal_num_tutor_assigned_pes],
          pes_are_assigned: data.fetch(:pes_are_assigned),
          is_deleted: data.fetch(:is_deleted, false),
          has_exercise_calculation: !pe_calculation_uuid.nil? || !spe_calculation_uuid.nil?
        )

        data.fetch(:assigned_exercises).each do |assigned_exercise|
          exercise_uuid = assigned_exercise.fetch(:exercise_uuid)

          assigned_exercises << AssignedExercise.new(
            uuid: assigned_exercise.fetch(:trial_uuid),
            assignment: assignments_hash[assignment_uuid],
            exercise_uuid: exercise_uuid,
            is_spe: assigned_exercise.fetch(:is_spe),
            is_pe: assigned_exercise.fetch(:is_pe)
          )
        end
      end

      # Record response saves a student response used to compute the CLUes
      record_responses = events_by_type['record_response'] || []
      record_responses.group_by do |record_response|
        record_response.fetch(:event_data).fetch(:response_uuid)
      end.each do |response_uuid, record_responses|
        last_record_response = record_responses.last
        data = last_record_response.fetch(:event_data)
        responded_at = data.fetch(:responded_at)

        responses_hash[response_uuid] = Response.new(
          uuid: response_uuid,
          ecosystem_uuid: data.fetch(:ecosystem_uuid),
          trial_uuid: data.fetch(:trial_uuid),
          student_uuid: data.fetch(:student_uuid),
          exercise_uuid: data.fetch(:exercise_uuid),
          first_responded_at: responded_at,
          last_responded_at: responded_at,
          is_correct: data.fetch(:is_correct),
          is_used_in_clue_calculations: false,
          is_used_in_exercise_calculations: false,
          is_used_in_response_count: false,
          is_used_in_student_history: false
        )
      end

      course.sequence_number = limit_sequence_number

      course
    end.compact

    # Update all the records in as few queries as possible

    results << EcosystemPreparation.import(
      ecosystem_preparations, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    )

    results << BookContainerMapping.import(
      book_container_mappings, validate: false, on_duplicate_key_ignore: {
        conflict_target: [
          :from_book_container_uuid,
          :from_ecosystem_uuid,
          :to_ecosystem_uuid
        ]
      }
    )

    # Chain mappings
    from_ecosystem_uuids = book_container_mappings.map(&:from_ecosystem_uuid)
    to_ecosystem_uuids = book_container_mappings.map(&:to_ecosystem_uuid)

    to_from_mappings = from_ecosystem_uuids.empty? ?
                         [] : BookContainerMapping.where(to_ecosystem_uuid: from_ecosystem_uuids)
    from_to_mappings = to_ecosystem_uuids.empty? ?
                         [] : BookContainerMapping.where(from_ecosystem_uuid: to_ecosystem_uuids)

    grouped_to_from_mappings = Hash.new do |hash, key|
      hash[key] = Hash.new { |hash, key| hash[key] = [] }
    end
    to_from_mappings.each do |tfm|
      grouped_to_from_mappings[tfm.to_ecosystem_uuid][tfm.to_book_container_uuid] << tfm
    end
    grouped_from_to_mappings = Hash.new do |hash, key|
      hash[key] = Hash.new { |hash, key| hash[key] = [] }
    end
    from_to_mappings.each do |ftm|
      grouped_from_to_mappings[ftm.from_ecosystem_uuid][ftm.from_book_container_uuid] << ftm
    end

    chain_mappings = book_container_mappings.flat_map do |bcm|
      from_ecosystem_uuid = bcm.from_ecosystem_uuid
      to_ecosystem_uuid = bcm.to_ecosystem_uuid
      from_book_container_uuid = bcm.from_book_container_uuid
      to_book_container_uuid = bcm.to_book_container_uuid

      to_from_mappings = grouped_to_from_mappings[from_ecosystem_uuid][from_book_container_uuid]
      from_to_mappings = grouped_from_to_mappings[to_ecosystem_uuid][to_book_container_uuid]

      to_from_mappings.map do |tfm|
        next if tfm.from_ecosystem_uuid == to_ecosystem_uuid

        BookContainerMapping.new(
          uuid: SecureRandom.uuid,
          from_ecosystem_uuid: tfm.from_ecosystem_uuid,
          to_ecosystem_uuid: to_ecosystem_uuid,
          from_book_container_uuid: tfm.from_book_container_uuid,
          to_book_container_uuid: to_book_container_uuid
        )
      end + from_to_mappings.map do |ftm|
        next if ftm.to_ecosystem_uuid == from_ecosystem_uuid

        BookContainerMapping.new(
          uuid: SecureRandom.uuid,
          from_ecosystem_uuid: from_ecosystem_uuid,
          to_ecosystem_uuid: ftm.to_ecosystem_uuid,
          from_book_container_uuid: from_book_container_uuid,
          to_book_container_uuid: ftm.to_book_container_uuid
        )
      end
    end.compact

    # Reverse mappings
    reverse_mappings = (book_container_mappings + chain_mappings).group_by do |bcm|
      [ bcm.from_ecosystem_uuid, bcm.to_ecosystem_uuid, bcm.to_book_container_uuid ]
    end.map do |(from_ecosystem_uuid, to_ecosystem_uuid, to_book_container_uuid), bcms|
      # Skip if 1-to-many (reverse mapping would be invalid)
      next if bcms.size > 1

      from_book_container_uuid = bcms.first.from_book_container_uuid

      BookContainerMapping.new(
        uuid: SecureRandom.uuid,
        from_ecosystem_uuid: to_ecosystem_uuid,
        to_ecosystem_uuid: from_ecosystem_uuid,
        from_book_container_uuid: to_book_container_uuid,
        to_book_container_uuid: from_book_container_uuid
      )
    end.compact

    results << BookContainerMapping.import(
      chain_mappings + reverse_mappings, validate: false, on_duplicate_key_ignore: {
        conflict_target: [
          :from_book_container_uuid, :from_ecosystem_uuid, :to_ecosystem_uuid
        ]
      }
    )

    results << CourseContainer.import(
      course_containers_hash.values.sort_by(&CourseContainer.sort_proc),
      validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ], columns: [ :course_uuid, :student_uuids ]
      }
    )

    results << Student.import(
      students_hash.values.sort_by(&Student.sort_proc), validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ],
        columns: [ :course_uuid, :course_container_uuids ]
      }
    )

    results << Assignment.import(
      assignments_hash.values.sort_by(&Assignment.sort_proc),
      validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ],
        columns: [
          :course_uuid,
          :ecosystem_uuid,
          :student_uuid,
          :assignment_type,
          :opens_at,
          :due_at,
          :feedback_at,
          :assigned_book_container_uuids,
          :assigned_exercise_uuids,
          :goal_num_tutor_assigned_spes,
          :spes_are_assigned,
          :goal_num_tutor_assigned_pes,
          :pes_are_assigned,
          :is_deleted,
          :has_exercise_calculation
        ]
      }
    )

    results << AssignedExercise.import(
      assigned_exercises, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    )

    # NOTE: update happens when an answer is changed
    #       first_responded_at is not included here so it is never updated after set
    #       is_used_in_clue_calculations is here because the CLUes need to be recalculated
    #       exercise calculations, response counts and student history are unaffected
    results << Response.import(
      responses_hash.values.sort_by(&Response.sort_proc), validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ],
        columns: [
          :trial_uuid,
          :student_uuid,
          :exercise_uuid,
          :last_responded_at,
          :is_correct,
          :is_used_in_clue_calculations
        ]
      }
    )

    # Event side-effects

    unless course_uuids_with_changed_ecosystems.empty?
      # Get students in courses with updated ecosystems
      changed_student_uuids = Student
        .where(course_uuid: course_uuids_with_changed_ecosystems)
        .pluck(:uuid)

      # Mark student CLUes for recalculation for students in courses with updated ecosystems
      StudentClueCalculation.where(student_uuid: changed_student_uuids)
                            .ordered_update_all(recalculate_at: current_time)
    end

    unless course_uuids_with_changed_rosters.empty?
      # Get course containers in courses with updated rosters
      changed_course_container_uuids = CourseContainer
        .where(course_uuid: course_uuids_with_changed_rosters)
        .pluck(:uuid)

      # Mark teacher CLUes for recalculation for course containers in courses with updated rosters
      TeacherClueCalculation.where(course_container_uuid: changed_course_container_uuids)
                            .ordered_update_all(recalculate_at: current_time)
    end

    unless assignments_hash.empty?
      assignment_uuids = assignments_hash.keys
      assigned_exercise_uuids = assigned_exercises.map(&:uuid)

      # Find relevant ExerciseCalculations
      # The ExerciseCalculation lock ensures we don't miss updates on
      # concurrent Assignment and AlgorithmExerciseCalculation inserts
      exercise_calculation_uuids = ExerciseCalculation.where(
        <<~WHERE_SQL
          "exercise_calculations"."uuid" IN (
            #{
              ExerciseCalculation
                .select(:uuid)
                .joins(:assignments)
                .where(assignments: { uuid: assignment_uuids })
                .to_sql
            }
            UNION ALL
            #{
              ExerciseCalculation
                .select(:uuid)
                .joins(
                  algorithm_exercise_calculations: :student_pes,
                  student: { assignments: :assigned_exercises }
                )
                .where('"assigned_exercises"."exercise_uuid" = "student_pes"."exercise_uuid"')
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              ExerciseCalculation
                .select(:uuid)
                .joins(assignments: :assignment_pes, student: { assignments: :assigned_exercises })
                .where('"assigned_exercises"."exercise_uuid" = "assignment_pes"."exercise_uuid"')
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              ExerciseCalculation
                .select(:uuid)
                .joins(assignments: :assignment_spes, student: { assignments: :assigned_exercises })
                .where('"assigned_exercises"."exercise_uuid" = "assignment_spes"."exercise_uuid"')
                .where(assigned_exercises: { uuid: assigned_exercise_uuids })
                .to_sql
            }
            UNION ALL
            #{
              ExerciseCalculation
                .select(:uuid)
                .joins(:algorithm_exercise_calculations)
                .where(
                  algorithm_exercise_calculations: {
                    uuid: used_algorithm_exercise_calculation_uuids
                  }
                )
                .to_sql
            }
          )
        WHERE_SQL
      )
      .ordered
      .lock('FOR NO KEY UPDATE OF "exercise_calculations"')
      .pluck(:uuid)

      # Recalculate Assignment PEs and SPEs for updated assignments and
      # Assignment PEs and SPEs that conflict with the AssignedExercises that were just
      # created to prevent any assignment from getting a PE or SPE that was already used elsewhere
      assignment_uuids_by_exercise_calculation_uuid = Hash.new { |hash, key| hash[key] = [] }
      ecu = ec[:uuid].as('"exercise_calculation_uuid"')
      aeeu = AssignedExercise.arel_table[:exercise_uuid]
      Assignment.from(
        <<~FROM_SQL
          (#{
            Assignment
              .select(:uuid, ecu)
              .joins(:exercise_calculation)
              .where(uuid: assignment_uuids)
              .to_sql
          }
          UNION
          #{
            Assignment
              .select(:uuid, ecu)
              .joins(
                :assignment_pes,
                exercise_calculation: { student: { assignments: :assigned_exercises } }
              )
              .where(aeeu.eq(AssignmentPe.arel_table[:exercise_uuid]))
              .where(
                exercise_calculation: {
                  student: {
                    assignments: { assigned_exercises: { uuid: assigned_exercise_uuids } }
                  }
                }
              )
              .to_sql
          }
          UNION
          #{
            Assignment
              .select(:uuid, ecu)
              .joins(
                :assignment_spes,
                exercise_calculation: { student: { assignments: :assigned_exercises } }
              )
              .where(aeeu.eq(AssignmentSpe.arel_table[:exercise_uuid]))
              .where(
                exercise_calculation: {
                  student: {
                    assignments: { assigned_exercises: { uuid: assigned_exercise_uuids } }
                  }
                }
              )
              .to_sql
          }) AS "assignments"
        FROM_SQL
      )
      .pluck(:uuid, as[:exercise_calculation_uuid])
      .each do |uuid, exercise_calculation_uuid|
        assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid] << uuid
      end

      used_exercise_calculations_uuids = []
      algorithm_exercise_calculation_values = []
      AlgorithmExerciseCalculation
        .where(exercise_calculation_uuid: exercise_calculation_uuids)
        .ordered
        .lock('FOR NO KEY UPDATE')
        .pluck(:uuid, :exercise_calculation_uuid, :pending_assignment_uuids)
        .each do |uuid, exercise_calculation_uuid, pending_assignment_uuids|
        used_exercise_calculations_uuids << exercise_calculation_uuid \
          if used_algorithm_exercise_calculation_uuids.include? uuid

        assignment_uuids = assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid]
        # Don't bother updating records where assignment_uuids is empty
        algorithm_exercise_calculation_values << [
          uuid, (pending_assignment_uuids + assignment_uuids).uniq
        ] unless assignment_uuids.empty?
      end

      ExerciseCalculation.where(uuid: used_exercise_calculations_uuids)
                         .ordered_update_all(is_used_in_assignments: true) \
        unless used_exercise_calculations_uuids.empty?

      unless algorithm_exercise_calculation_values.empty?
        algorithm_exercise_calculation_uuids = algorithm_exercise_calculation_values.map(&:first)
        AlgorithmExerciseCalculation.update_all(
          <<~UPDATE_SQL
            "pending_assignment_uuids" = "values"."pending_assignment_uuids"
            FROM (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
              ("uuid", "pending_assignment_uuids")
            WHERE "algorithm_exercise_calculations"."uuid" = "values"."uuid"::uuid
          UPDATE_SQL
        )
      end

      # Anti-cheating: we don't allow StudentPes that have already been assigned elsewhere
      # Recalculate Student PEs that conflict with the AssignedExercises that were just created
      AlgorithmExerciseCalculation
        .joins(
          :student_pes, exercise_calculation: { student: { assignments: :assigned_exercises } }
        )
        .where('"assigned_exercises"."exercise_uuid" = "student_pes"."exercise_uuid"')
        .where(assigned_exercises: { uuid: assigned_exercise_uuids })
        .ordered_update_all(is_pending_for_student: true) unless assigned_exercise_uuids.empty?
    end

    # No sort needed because already locked above
    results << Course.import(
      courses, validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ],
        columns: [
          :sequence_number,
          :ecosystem_uuid,
          :starts_at,
          :ends_at,
          :course_excluded_exercise_uuids,
          :course_excluded_exercise_group_uuids,
          :global_excluded_exercise_uuids,
          :global_excluded_exercise_group_uuids
        ]
      }
    )

    [ course_uuids_to_requery, results, total_events ]
  end
end

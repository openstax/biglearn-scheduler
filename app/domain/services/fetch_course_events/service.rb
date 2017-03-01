class Services::FetchCourseEvents::Service
  # create_course is already included in the metadata
  # and would not be useful to look at besides error-checking

  # Local query only calculates new CLUes/PEs/SPEs/Practice when receiving updates,
  # so update_course_active_dates is unnecessary
  RELEVANT_EVENT_TYPES = [
    :prepare_course_ecosystem,
    :update_course_ecosystem,
    :update_roster,
    :update_globally_excluded_exercises,
    :update_course_excluded_exercises,
    :create_update_assignment,
    :record_response
  ]

  def process
    start_time = Time.now
    Rails.logger.tagged 'FetchCourseEvents' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    Course.transaction do
      course_event_requests = []
      courses_by_course_uuid = Course.all.map do |course|
        course_event_requests << { course: course, event_types: RELEVANT_EVENT_TYPES }

        [ course.uuid, course ]
      end.to_h
      course_event_responses = OpenStax::Biglearn::Api.fetch_course_events(course_event_requests)
                                                      .values
                                                      .map(&:deep_symbolize_keys)

      ecosystem_preparations = []
      course_uuids_with_changed_ecosystems = []
      book_container_mappings = []
      course_containers = []
      students = []
      assignments = []
      responses = []
      response_uuids = []
      courses = course_event_responses.map do |course_event_response|
        events = course_event_response.fetch :events
        next if events.empty?

        course_uuid = course_event_response.fetch :course_uuid
        course = courses_by_course_uuid.fetch course_uuid

        events_by_type = events.group_by{ |event| event.fetch(:event_type) }

        # Prepare course ecosystem is stored for a future update
        # and used as a signal to start precomputing CLUes and PracticeWorstAreas
        prepare_ecosystems = events_by_type['prepare_course_ecosystem'] || []
        course_ecosystem_preparations = prepare_ecosystems.map do |prepare_course_ecosystem|
          data = prepare_course_ecosystem.fetch(:event_data)

          ecosystem_map = data.fetch(:ecosystem_map)
          from_ecosystem_uuid = ecosystem_map.fetch(:from_ecosystem_uuid)
          to_ecosystem_uuid = ecosystem_map.fetch(:to_ecosystem_uuid)
          ecosystem_map.fetch(:book_container_mappings).each do |mapping|
            book_container_mappings << BookContainerMapping.new(
              uuid: SecureRandom.uuid,
              from_ecosystem_uuid: from_ecosystem_uuid,
              to_ecosystem_uuid: to_ecosystem_uuid,
              from_book_container_uuid: mapping.fetch(:from_book_container_uuid),
              to_book_container_uuid: mapping.fetch(:to_book_container_uuid)
            )
          end

          ecosystem_preparations << EcosystemPreparation.new(
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
          preparation = course_ecosystem_preparations.find{ |prep| prep.uuid == preparation_uuid }
          preparation ||= EcosystemPreparation.find_by uuid: preparation_uuid
          course.ecosystem_uuid = preparation.ecosystem_uuid
          course_uuids_with_changed_ecosystems << course.uuid
        end

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
            container_uuids_set = Set.new
            current_container_uuid = student.fetch(:container_uuid)
            student_uuid = student.fetch(:student_uuid)

            # Flatten the course tree structure into arrays of uuids
            until current_container_uuid.nil? ||
                  current_container_uuid == course_uuid ||
                  container_uuids_set.include?(current_container_uuid) do
              container_uuids_set << current_container_uuid
              student_uuids_by_container_uuid[current_container_uuid] << student_uuid

              current_container_uuid = parent_uuids_by_container_uuid[current_container_uuid]
            end

            students << Student.new(
              uuid: student_uuid,
              course_uuid: course_uuid,
              course_container_uuids: container_uuids_set.to_a
            )
          end

          containers.each do |course_container|
            container_uuid = course_container.fetch(:container_uuid)

            course_containers << CourseContainer.new(
              uuid: container_uuid,
              course_uuid: course_uuid,
              student_uuids: student_uuids_by_container_uuid[container_uuid],
              is_archived: course_container.fetch(:is_archived)
            )
          end
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
          exercises = data.fetch(:assigned_exercises)
          exercise_uuids = exercises.map { |exercise| exercise.fetch(:exercise_uuid) }

          exclusion_info = data.fetch(:exclusion_info, {})
          opens_at = exclusion_info[:opens_at]
          due_at = exclusion_info[:due_at]

          assignments << Assignment.new(
            uuid: assignment_uuid,
            course_uuid: course_uuid,
            ecosystem_uuid: ecosystem_uuid,
            student_uuid: data.fetch(:student_uuid),
            assignment_type: data.fetch(:assignment_type),
            opens_at: opens_at.nil? ? nil : DateTime.parse(opens_at),
            due_at: due_at.nil? ? nil : DateTime.parse(due_at),
            assigned_book_container_uuids: data.fetch(:assigned_book_container_uuids),
            assigned_exercise_uuids: exercise_uuids,
            goal_num_tutor_assigned_spes: data.fetch(:goal_num_tutor_assigned_spes),
            spes_are_assigned: data.fetch(:spes_are_assigned),
            goal_num_tutor_assigned_pes: data.fetch(:goal_num_tutor_assigned_pes),
            pes_are_assigned: data.fetch(:pes_are_assigned)
          )
        end

        # Record response saves a student response used to compute the CLUes
        record_responses = events_by_type['record_response'] || []
        record_responses.group_by do |record_response|
          record_response.fetch(:event_data).fetch(:trial_uuid)
        end.each do |trial_uuid, record_responses|
          last_record_response = record_responses.last
          data = last_record_response.fetch(:event_data)

          response_uuids << trial_uuid

          responses << Response.new(
            uuid: trial_uuid,
            student_uuid: data.fetch(:student_uuid),
            exercise_uuid: data.fetch(:exercise_uuid),
            responded_at: data.fetch(:responded_at),
            is_correct: data.fetch(:is_correct)
          )
        end

        course.sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max + 1

        course
      end.compact

      # Update all the records in as few queries as possible

      results = []

      results << Course.import(
        courses, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [
            :sequence_number,
            :ecosystem_uuid,
            :course_excluded_exercise_uuids,
            :course_excluded_exercise_group_uuids,
            :global_excluded_exercise_uuids,
            :global_excluded_exercise_group_uuids
          ]
        }
      )

      results << EcosystemPreparation.import(
        ecosystem_preparations, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :uuid ]
        }
      )

      results << BookContainerMapping.import(
        book_container_mappings, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :from_book_container_uuid, :from_ecosystem_uuid, :to_ecosystem_uuid ]
        }
      )

      results << CourseContainer.import(
        course_containers, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :course_uuid, :is_archived, :student_uuids ]
        }
      )

      results << Student.import(
        students, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :course_uuid, :course_container_uuids ]
        }
      )

      results << Assignment.import(
        assignments, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [
            :course_uuid,
            :ecosystem_uuid,
            :student_uuid,
            :assignment_type,
            :opens_at,
            :due_at,
            :assigned_book_container_uuids,
            :assigned_exercise_uuids,
            :goal_num_tutor_assigned_spes,
            :spes_are_assigned,
            :goal_num_tutor_assigned_pes,
            :pes_are_assigned
          ]
        }
      )

      # Mark SPEs/PEs for recalculation for updated Assignments
      assignment_uuids = assignments.map(&:uuid)
      AssignmentSpe.where(assignment_uuid: assignment_uuids).delete_all
      AssignmentPe.where(assignment_uuid: assignment_uuids).delete_all

      # Find other affected assignments and mark their SPEs/PEs for recalculation
      # if their Exercises have just been assigned
      spe = AssignmentSpe.arel_table
      pe = AssignmentPe.arel_table
      spe_queries = []
      pe_queries = []
      assignments.each do |assignment|
        student_uuid = assignment.student_uuid
        assigned_exercise_uuids = assignment.assigned_exercise_uuids

        spe_queries << spe[:student_uuid].eq(student_uuid).and(
                         spe[:exercise_uuid].in(assigned_exercise_uuids)
                       )

        pe_queries << pe[:student_uuid].eq(student_uuid).and(
                        pe[:exercise_uuid].in(assigned_exercise_uuids)
                      )
      end

      if spe_queries.any?
        spe_query = spe[:assignment_uuid].not_in(assignment_uuids).and(spe_queries.reduce(:or))
        affected_spe_assignment_uuids = AssignmentSpe.where(spe_query).pluck(:assignment_uuid)
        Assignment.where(uuid: affected_spe_assignment_uuids).update_all(spes_are_assigned: false)
        AssignmentSpe.where(spe_query).delete_all
      end

      if pe_queries.any?
        pe_query = pe[:assignment_uuid].not_in(assignment_uuids).and(pe_queries.reduce(:or))
        affected_pe_assignment_uuids = AssignmentPe.where(pe_query).pluck(:assignment_uuid)
        Assignment.where(uuid: affected_pe_assignment_uuids).update_all(pes_are_assigned: false)
        AssignmentPe.where(pe_query).delete_all
      end

      results << Response.import(
        responses, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [
            :student_uuid,
            :exercise_uuid,
            :responded_at,
            :is_correct
          ]
        }
      )

      # Mark CLUes for recalculation for updated course ecosystems and responses
      ResponseClue.where(uuid: response_uuids).delete_all
      ResponseClue.where(course_uuid: course_uuids_with_changed_ecosystems).delete_all

      Rails.logger.tagged 'FetchCourseEvents' do |logger|
        logger.info do
          course_events = course_event_responses.map do |response|
            response.fetch(:events).size
          end.reduce(0, :+)
          conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
          time = Time.now - start_time

          "Received: #{course_events} event(s) in #{courses.size} course(s)" +
          " - Conflicts: #{conflicts} - Took: #{time} second(s)"
        end
      end
    end
  end
end

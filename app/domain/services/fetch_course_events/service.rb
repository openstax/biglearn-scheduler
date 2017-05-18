class Services::FetchCourseEvents::Service
  COURSE_BATCH_SIZE = 100

  # create_course is already included in the metadata
  # and would not be useful to look at besides error-checking
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

  def process
    start_time = Time.now
    Rails.logger.tagged 'FetchCourseEvents' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    course_ids_to_query = Course.ids
    total_courses = course_ids_to_query.size

    results = []
    total_events = 0
    loop do
      course_ids = course_ids_to_query
      course_ids_to_query = []

      course_ids.each_slice(COURSE_BATCH_SIZE) do |course_ids|
        Course.transaction do
          course_event_requests = []
          courses_by_course_uuid = Course.where(id: course_ids).map do |course|
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
          assigned_exercises = []
          responses = []
          response_uuids = []
          courses = course_event_responses.map do |course_event_response|
            events = course_event_response.fetch :events
            num_events = events.size
            next if num_events == 0

            total_events += num_events

            course_uuid = course_event_response.fetch :course_uuid
            course = courses_by_course_uuid.fetch course_uuid

            course_ids_to_query << course.id \
              unless course_event_response.fetch(:is_gap) || course_event_response.fetch(:is_end)

            events_by_type = events.group_by { |event| event.fetch(:event_type) }

            # Prepare course ecosystem is stored for a future update
            # and used as a signal to start precomputing CLUes and PracticeWorstAreas
            prepare_ecosystems = events_by_type['prepare_course_ecosystem'] || []
            course_ecosystem_preparations = prepare_ecosystems.map do |prepare_course_ecosystem|
              data = prepare_course_ecosystem.fetch(:event_data)

              ecosystem_map = data.fetch(:ecosystem_map)

              # Forward mappings
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

              EcosystemPreparation.new(
                uuid: data.fetch(:preparation_uuid),
                course_uuid: data.fetch(:course_uuid),
                ecosystem_uuid: data.fetch(:ecosystem_uuid)
              ).tap do |ecosystem_preparation|
                ecosystem_preparations << ecosystem_preparation
              end
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

                # pes_are_assigned starts as true because there is no point in trying to assign PEs
                # until we have some CLUes, at which point it will be set to false
                # pes_are_assigned is NOT part of ON CONFLICT DO UPDATE so after the first time
                # it will be controlled only by the other background tasks
                students << Student.new(
                  uuid: student_uuid,
                  course_uuid: course_uuid,
                  course_container_uuids: container_uuids,
                  pes_are_assigned: true
                )
              end

              containers.each do |course_container|
                container_uuid = course_container.fetch(:container_uuid)

                course_containers << CourseContainer.new(
                  uuid: container_uuid,
                  course_uuid: course_uuid,
                  student_uuids: student_uuids_by_container_uuid[container_uuid]
                )
              end
            end

            # Update course active dates is used to exclude past courses from calculations
            update_course_active_dates = events_by_type['update_course_active_dates'] || []
            # TODO: Handle update course active dates

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
              exercise_uuids = exercises.map { |exercise| exercise.fetch(:exercise_uuid) }.uniq

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
                goal_num_tutor_assigned_spes: data[:goal_num_tutor_assigned_spes],
                spes_are_assigned: data.fetch(:spes_are_assigned),
                goal_num_tutor_assigned_pes: data[:goal_num_tutor_assigned_pes],
                pes_are_assigned: data.fetch(:pes_are_assigned)
              )

              data.fetch(:assigned_exercises).each do |assigned_exercise|
                assigned_exercises << AssignedExercise.new(
                  uuid: assigned_exercise.fetch(:trial_uuid),
                  assignment_uuid: assignment_uuid,
                  exercise_uuid: assigned_exercise.fetch(:exercise_uuid),
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

              response_uuids << response_uuid

              responses << Response.new(
                uuid: response_uuid,
                ecosystem_uuid: data.fetch(:ecosystem_uuid),
                trial_uuid: data.fetch(:trial_uuid),
                student_uuid: data.fetch(:student_uuid),
                exercise_uuid: data.fetch(:exercise_uuid),
                responded_at: data.fetch(:responded_at),
                is_correct: data.fetch(:is_correct),
                used_in_clue_calculations: false,
                used_in_ecosystem_matrix_updates: false
              )
            end

            course.sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max + 1

            course
          end.compact

          # Update all the records in as few queries as possible

          results = []

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

          # Chain mappings
          from_ecosystem_uuids = book_container_mappings.map(&:from_ecosystem_uuid)
          to_ecosystem_uuids = book_container_mappings.map(&:to_ecosystem_uuid)

          to_from_mappings = BookContainerMapping.where(to_ecosystem_uuid: from_ecosystem_uuids)
          from_to_mappings = BookContainerMapping.where(from_ecosystem_uuid: to_ecosystem_uuids)

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
              conflict_target: [ :from_book_container_uuid, :from_ecosystem_uuid, :to_ecosystem_uuid ]
            }
          )

          results << CourseContainer.import(
            course_containers, validate: false, on_duplicate_key_update: {
              conflict_target: [ :uuid ], columns: [ :course_uuid, :student_uuids ]
            }
          )

          results << Student.import(
            students, validate: false, on_duplicate_key_update: {
              conflict_target: [ :uuid ],
              columns: [ :course_uuid, :course_container_uuids ]
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

          results << AssignedExercise.import(
            assigned_exercises, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
          )

          results << Response.import(
            responses, validate: false, on_duplicate_key_update: {
              conflict_target: [ :uuid ],
              columns: [
                :trial_uuid,
                :student_uuid,
                :exercise_uuid,
                :responded_at,
                :is_correct
              ]
            }
          )

          # Event side-effects
          # Get students in courses with updated ecosystems
          affected_student_uuids = Student.where(course_uuid: course_uuids_with_changed_ecosystems)
                                          .pluck(:uuid)

          # Mark CLUes and ecosystem matrices for recalculation
          # for students in courses with updated ecosystems
          Response.where(student_uuid: affected_student_uuids)
                  .update_all(used_in_clue_calculations: false,
                              used_in_ecosystem_matrix_updates: false)

          # Get updated assignments
          updated_assignment_uuids = assignments.map(&:uuid)

          # Updated assignments and students in courses with changed ecosystems need complete SPE/PE
          # recalculations, including re-running the scheduler code
          AlgorithmAssignmentSpeCalculation
            .joins(:assignment_spe_calculation)
            .where(assignment_spe_calculations: { assignment_uuid: updated_assignment_uuids })
            .delete_all
          AlgorithmAssignmentPeCalculation
            .joins(:assignment_pe_calculation)
            .where(assignment_pe_calculations: { assignment_uuid: updated_assignment_uuids })
            .delete_all
          AlgorithmStudentPeCalculation
            .joins(:student_pe_calculation)
            .where(student_pe_calculations: { student_uuid: affected_student_uuids })
            .delete_all

          AssignmentSpeCalculation.where(assignment_uuid: updated_assignment_uuids).delete_all
          AssignmentPeCalculation.where(assignment_uuid: updated_assignment_uuids).delete_all
          StudentPeCalculation.where(student_uuid: affected_student_uuids).delete_all

          # Find affected assignments and PracticeWorstAreasExercises for students with updated
          # assignments (with the same exercise_uuids) and mark their SPEs/PEs for recalculation
          aspec = AssignmentSpeCalculation.arel_table
          aspece = AssignmentSpeCalculationExercise.arel_table
          apec = AssignmentPeCalculation.arel_table
          apece = AssignmentPeCalculationExercise.arel_table
          spec = StudentPeCalculation.arel_table
          spece = StudentPeCalculationExercise.arel_table
          aspece_queries = [ aspec[:assignment_uuid].in(updated_assignment_uuids) ]
          apece_queries =  [ apec[:assignment_uuid].in(updated_assignment_uuids)  ]
          spece_queries =  [ spec[:student_uuid].in(affected_student_uuids)       ]
          assignments.each do |assignment|
            assignment_uuid = assignment.uuid
            student_uuid = assignment.student_uuid
            assigned_exercise_uuids = assignment.assigned_exercise_uuids

            aspece_queries << aspec[:student_uuid].eq(student_uuid).and(
                                aspece[:exercise_uuid].in(assigned_exercise_uuids)
                              )

            apece_queries << apec[:student_uuid].eq(student_uuid).and(
                               apece[:exercise_uuid].in(assigned_exercise_uuids)
                             )

            spece_queries << spec[:student_uuid].eq(student_uuid).and(
                               spece[:exercise_uuid].in(assigned_exercise_uuids)
                             )
          end

          aspece_query = aspece_queries.reduce(:or)
          affected_assignment_spe_calculation_uuids =
            AssignmentSpeCalculationExercise.joins(:assignment_spe_calculation)
                                            .where(aspece_query)
                                            .pluck(:assignment_spe_calculation_uuid)
          AssignmentSpeCalculation
            .where(uuid: affected_assignment_spe_calculation_uuids)
            .delete_all
          AssignmentSpeCalculationExercise
            .where(assignment_spe_calculation_uuid: affected_assignment_spe_calculation_uuids)
            .delete_all
          AlgorithmAssignmentSpeCalculation
            .where(assignment_spe_calculation_uuid: affected_assignment_spe_calculation_uuids)
            .delete_all

          apece_query = apece_queries.reduce(:or)
          affected_assignment_pe_calculation_uuids =
            AssignmentPeCalculationExercise.joins(:assignment_pe_calculation)
                                           .where(apece_query)
                                           .pluck(:assignment_pe_calculation_uuid)
          AssignmentPeCalculation
            .where(uuid: affected_assignment_pe_calculation_uuids)
            .delete_all
          AssignmentPeCalculationExercise
            .where(assignment_pe_calculation_uuid: affected_assignment_pe_calculation_uuids)
            .delete_all
          AlgorithmAssignmentPeCalculation
            .where(assignment_pe_calculation_uuid: affected_assignment_pe_calculation_uuids)
            .delete_all

          spece_query = spece_queries.reduce(:or)
          affected_student_pe_calculation_uuids =
            StudentPeCalculationExercise.joins(:student_pe_calculation)
                                        .where(spece_query)
                                        .pluck(:student_pe_calculation_uuid)
          StudentPeCalculation
            .where(uuid: affected_student_pe_calculation_uuids)
            .delete_all
          StudentPeCalculationExercise
            .where(student_pe_calculation_uuid: affected_student_pe_calculation_uuids)
            .delete_all
          AlgorithmStudentPeCalculation
            .where(student_pe_calculation_uuid: affected_student_pe_calculation_uuids)
            .delete_all

          # This is done last because the sequence_number update marks events as processed
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
        end
      end

      break if course_ids_to_query.empty?
    end

    Rails.logger.tagged 'FetchCourseEvents' do |logger|
      logger.debug do
        conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
        time = Time.now - start_time

        "Received: #{total_events} event(s) from #{total_courses} course(s)" +
        " with #{conflicts} conflict(s) in #{time} second(s)"
      end
    end
  end
end

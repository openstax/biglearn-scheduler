RELEVANT_COURSE_EVENT_TYPES = [
  :prepare_course_ecosystem,
  :update_course_ecosystem,
  :update_roster,
  :update_globally_excluded_exercises,
  :update_course_excluded_exercises,
  :create_update_assignment,
  :record_response
]

namespace :fetch_events do
  task courses: :environment do
    start_time = Time.now
    Rails.logger.tagged 'fetch_events:courses' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    course_event_requests = []
    Course.transaction do
      ecosystem_uuids_by_course_uuid = Course.all.map do |course|
        course_event_requests << { course: course, event_types: RELEVANT_COURSE_EVENT_TYPES }

        [ course.uuid, course.ecosystem_uuid ]
      end.to_h
      course_event_responses = OpenStax::Biglearn::Api.fetch_course_events(course_event_requests)
                                                      .values
                                                      .map(&:deep_symbolize_keys)

      ecosystem_preparations = []
      course_containers = []
      students = []
      assignments = []
      responses = []
      courses = course_event_responses.map do |course_event_response|
        events = course_event_response.fetch(:events)
        next if events.empty?

        course_uuid = course_event_response.fetch(:course_uuid)
        ecosystem_uuid = ecosystem_uuids_by_course_uuid.fetch(course_uuid)
        events = course_event_response.fetch(:events)
        sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max
        events_by_type = events.group_by{ |event| event.fetch(:event_type) }

        Course.new(uuid: course_uuid,
                   ecosystem_uuid: ecosystem_uuid,
                   sequence_number: sequence_number).tap do |course|

          # Create course is already included in the metadata
          # and would not be useful to look at besides error-checking

          # Prepare course ecosystem is stored for a future update
          # and used as a signal to start precomputing CLUes and PracticeWorstAreas
          prepare_ecosystems = events_by_type['prepare_course_ecosystem'] || []
          course_ecosystem_preparations = prepare_ecosystems.map do |prepare_course_ecosystem|
            data = prepare_course_ecosystem.fetch(:event_data)

            ecosystem_preparations << EcosystemPreparation.new(
              uuid: prepare_course_ecosystem.fetch(:event_uuid),
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
          end

          # Update roster changes the students and periods we compute CLUes for
          update_rosters = events_by_type['update_roster'] || []
          last_roster = update_rosters.last
          if last_roster.present?
            data = last_roster.fetch(:event_data)
            course_containers = data.fetch(:course_containers).reject{ |cc| cc.fetch :is_archived }

            parent_uuids_by_container_uuid = course_containers.map do |container|
              container_uuid = course_container.fetch(:container_uuid)

              course_containers << CourseContainer.new(
                uuid: container_uuid,
                course_uuid: last_roster.fetch(:course_uuid)
              )

              [ container_uuid, course_container.fetch(:parent_container_uuid) ]
            end.to_h

            data.fetch(:students).each do |student|
              container_uuids = []
              current_container_uuid = student.fetch(:container_uuid)
              # Flatten the course tree structure into an array of uuids
              until current_container_uuid.nil? || current_container_uuid == course_uuid do
                container_uuids << current_container_uuid
                current_container_uuid = parent_uuids_by_container_uuid[current_container_uuid]
              end

              students << Student.new(
                uuid: student.fetch(:student_uuid),
                course_container_uuids: container_uuids
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
            create_update_assignment.fetch(:assignment_uuid)
          end.each do |assignment_uuid, create_update_assignments|
            last_create_update_assignment = create_update_assignments.last

            assigned_book_container_uuids = \
              last_create_update_assignment.fetch(:assigned_book_container_uuids)
            exercises = last_create_update_assignment.fetch(:assigned_exercises)
            exercise_uuids = exercises.map { |exercise| exercise.fetch(:exercise_uuid) }
            goal_num_spes = last_create_update_assignment.fetch(:goal_num_tutor_assigned_spes)
            goal_num_pes = last_create_update_assignment.fetch(:goal_num_tutor_assigned_pes)

            assignments << Assignment.new(
              uuid: assignment_uuid,
              course_uuid: last_create_update_assignment.fetch(:course_uuid),
              student_uuid: last_create_update_assignment.fetch(:student_uuid),
              assignment_type: last_create_update_assignment.fetch(:assignment_type),
              assigned_book_container_uuids: assigned_book_container_uuids,
              assigned_exercise_uuids: exercise_uuids,
              goal_num_spes: goal_num_spes,
              goal_num_pes: goal_num_pes
            )
          end

          # Record response saves a student response used to compute the CLUes
          record_responses = events_by_type['record_response'] || []
          record_responses.group_by do |record_response|
            record_response.fetch(:response_uuid)
          end.each do |response_uuid, record_responses|
            last_record_response = record_responses.last

            responses << Response.new(
              uuid: response_uuid,
              student_uuid: last_record_response.fetch(:student_uuid),
              exercise_uuid: last_record_response.fetch(:exercise_uuid),
              is_correct: last_record_response.fetch(:is_correct)
            )
          end

        end
      end.compact

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
        ecosystem_preparations, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :course_uuid, :ecosystem_uuid ]
        }
      )

      results << CourseContainer.import(
        course_containers, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :course_uuid ]
        }
      )

      results << Student.import(
        students, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :course_container_uuids ]
        }
      )

      results << Assignment.import(
        assignments, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [
            :course_uuid,
            :student_uuid,
            :assignment_type,
            :assigned_book_container_uuids,
            :assigned_exercise_uuids,
            :goal_num_spes,
            :goal_num_pes
          ]
        }
      )

      results << Response.import(
        responses, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :student_uuid, :exercise_uuid, :is_correct ]
        }
      )

      Rails.logger.tagged 'fetch_events:courses' do |logger|
        logger.info do
          course_events = course_event_responses.map{ |response| response.fetch(:events).size }
                                                .reduce(0, :+)
          failures = results.map { |result| result.failed_instances.size }.reduce(0, :+)
          num_inserts = results.map(&:num_inserts).reduce(0, :+)

          "Received: #{course_events} events in #{courses.size} courses" +
          " - Successful: #{num_inserts} insert(s) - Failed: #{failures} insert(s)" +
          " - Took: #{Time.now - start_time} second(s)"
        end
      end
    end
  end
end

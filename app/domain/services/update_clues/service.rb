class Services::UpdateClues::Service
  BATCH_SIZE = 1000
  Z_ALPHA = 0.68

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    ee = EcosystemExercise.arel_table
    rsp = Response.arel_table

    # Do all the processing in batches to avoid OOM problems
    total_responses = 0
    loop do
      num_responses = Response.transaction do
        # ResponseClue records keep track of which Responses have been used in CLUes and
        # are cleared after every ecosystem update
        responses = Response.joins(:course, :exercise)
                            .left_outer_joins(:response_clue)
                            .where(response_clues: { uuid: nil })
                            .take(BATCH_SIZE)

        # Build some hashes to minimize the number of queries

        # Map the students to courses, course containers and worst CLUes
        student_uuids = responses.map(&:student_uuid)
        course_uuid_by_student_uuid = {}
        course_container_uuids_by_student_uuids = {}
        worst_clue_book_container_uuid_by_student_uuid = {}
        worst_clue_value_by_student_uuid = {}
        Student.where(uuid: student_uuids)
               .with_worst_clues
               .pluck(
                 :uuid,
                 :course_uuid,
                 :course_container_uuids,
                 :worst_clue_book_container_uuid,
                 :worst_clue_value
               ).each do |
                 uuid,
                 course_uuid,
                 course_container_uuids,
                 worst_clue_book_container_uuid,
                 worst_clue_value
               |
          course_uuid_by_student_uuid[uuid] = course_uuid
          course_container_uuids_by_student_uuids[uuid] = course_container_uuids
          worst_clue_book_container_uuid_by_student_uuid[uuid] = worst_clue_book_container_uuid
          worst_clue_value_by_student_uuid[uuid] = worst_clue_value
        end

        # Map the course containers back to students
        course_container_uuids = course_container_uuids_by_student_uuids.values.flatten
        student_uuids_by_course_container_uuids = \
          CourseContainer.where(uuid: course_container_uuids)
                         .pluck(:uuid, :student_uuids)
                         .to_h

        # Map the courses to ecosystems
        course_uuids = course_uuid_by_student_uuid.values
        ecosystem_uuid_by_course_uuid = Course.where(uuid: course_uuids)
                                              .pluck(:uuid, :ecosystem_uuid)
                                              .to_h

        # Map the exercise_uuids to exercise_group_uuids
        exercise_uuids = responses.map(&:exercise_uuid)
        exercise_group_uuid_by_exercise_uuid = Exercise.where(uuid: exercise_uuids)
                                                       .pluck(:uuid, :group_uuid)
                                                       .to_h

        # Build a query to obtain the book_container_uuids for the new Responses
        # Mark the responses as used in CLUe calculations
        # (in case we don't use them later because they got removed from the book or something)
        used_responses = []
        ee_queries = responses.map do |response|
          student_uuid = response.student_uuid
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]

          exercise_uuid = response.exercise_uuid
          exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]

          used_responses << [response.uuid, course_uuid]

          ee[:ecosystem_uuid].eq(ecosystem_uuid).and(
            ee[:exercise_group_uuid].eq(exercise_group_uuid)
          )
        end.compact.reduce(:or)

        # Map the ecosystem_uuids and exercise_group_uuids to book_container_uuids
        book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        EcosystemExercise.where(ee_queries)
                         .pluck(:ecosystem_uuid, :exercise_group_uuid, :book_container_uuids)
                         .each do |ecosystem_uuid, exercise_group_uuid, book_container_uuids|
          book_container_uuids_map[ecosystem_uuid][exercise_group_uuid] = book_container_uuids
        end unless ee_queries.nil?

        # Map the book_container_uuids to ecosystem_uuids and back to exercise_uuids
        book_container_uuids = book_container_uuids_map.values.map(&:values).flatten
        ecosystem_uuid_by_book_container_uuid = {}
        exercise_uuids_by_book_container_uuids = Hash.new { |hash, key| hash[key] = [] }
        ExercisePool.where(book_container_uuid: book_container_uuids)
                    .pluck(:ecosystem_uuid, :book_container_uuid, :exercise_uuids, :use_for_clue)
                    .each do |ecosystem_uuid, book_container_uuid, exercise_uuids, use_for_clue|
          ecosystem_uuid_by_book_container_uuid[book_container_uuid] = ecosystem_uuid
          next unless use_for_clue

          exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
        end

        # Find all relevant exercise group_uuids
        # (all exercise group_uuids in the matching book_containers)
        exercise_uuids = exercise_uuids_by_book_container_uuids.values.flatten
        exercise_group_uuids = Exercise.where(uuid: exercise_uuids).pluck(:group_uuid)

        # Re-map the exercise_uuids to exercise_group_uuids since the exercises may have changed
        exercise_group_uuid_by_exercise_uuid = Exercise.where(group_uuid: exercise_group_uuids)
                                                       .pluck(:uuid, :group_uuid)
                                                       .to_h

        # Collect the CLUes that need to be updated and build the final Response query
        student_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
        teacher_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
        response_queries = responses.map do |response|
          student_uuid = response.student_uuid
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]
          exercise_uuid = response.exercise_uuid
          exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]

          # Find all book containers that contain the given exercise and all their exercises
          # exercise_group_uuid can be nil here...
          # this simply means the exercise was removed from the book and should not count for CLUes
          book_container_uuids = book_container_uuids_map[ecosystem_uuid].fetch exercise_group_uuid,
                                                                                []
          exercise_uuids = \
            exercise_uuids_by_book_container_uuids.values_at(*book_container_uuids).flatten

          # Find all course containers that contain the given student
          course_container_uuids = course_container_uuids_by_student_uuids.fetch student_uuid, []

          book_container_uuids.each do |book_container_uuid|
            student_clues_to_update[book_container_uuid] << student_uuid

            teacher_clues_to_update[book_container_uuid].concat course_container_uuids
          end

          # All responses from students in the same course containers
          # that refer to any exercise in the same book containers should be considered
          student_uuids = \
            student_uuids_by_course_container_uuids.values_at(*course_container_uuids).flatten
          rsp[:student_uuid].in(student_uuids).and rsp[:exercise_uuid].in(exercise_uuids)
        end.compact.reduce(:or)

        # Map student_uuids and exercise_group_uuids to correctness information
        # Take only the latest answer for each exercise_group_uuid
        # Mark responses found here as used in CLUe calculations
        responses_map = Hash.new { |hash, key| hash[key] = {} }
        Response.where(response_queries)
                .order(:responded_at)
                .pluck(:uuid, :student_uuid, :exercise_uuid, :is_correct)
                .each do |uuid, student_uuid, exercise_uuid, is_correct|
          exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]
          if exercise_group_uuid.nil?
            Rails.logger.tagged('UpdateClues') do |logger|
              logger.warn do
                "Response skipped due to no information about exercise #{exercise_uuid}"
              end
            end

            next
          end

          responses_map[student_uuid][exercise_group_uuid] = is_correct

          course_uuid = course_uuid_by_student_uuid[student_uuid]
          used_responses << [uuid, course_uuid]
        end unless response_queries.nil?

        # Calculate student CLUes
        student_clues = []
        student_clue_requests = []
        student_uuids_to_update_worst_areas_exercises = []
        student_clues_to_update.each do |book_container_uuid, student_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            Rails.logger.tagged('UpdateClues') do |logger|
              logger.warn do
                "Student CLUe skipped due to no information about book container #{
                  book_container_uuid
                }"
              end
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                     .compact
                                                                     .uniq

          student_uuids.uniq.each do |student_uuid|
            worst_clue_book_container_uuid = \
              worst_clue_book_container_uuid_by_student_uuid[student_uuid]
            worst_clue_value = worst_clue_value_by_student_uuid[student_uuid]

            student_responses = responses_map[student_uuid]
            clue_responses = student_responses.values_at(*exercise_group_uuids).compact.flatten
            clue_data = calculate_clue_data(clue_responses).merge(ecosystem_uuid: ecosystem_uuid)
            clue_value = clue_data.fetch(:most_likely)
            is_real = clue_data.fetch(:is_real)

            student_uuids_to_update_worst_areas_exercises << student_uuid \
              if is_real && (
                   worst_clue_book_container_uuid.nil? || worst_clue_value.nil? ||
                   worst_clue_book_container_uuid == book_container_uuid ||
                   worst_clue_value >= clue_value
                 )

            student_clues << StudentClue.new(
              uuid: SecureRandom.uuid,
              student_uuid: student_uuid,
              book_container_uuid: book_container_uuid,
              value: clue_value
            ) if is_real

            student_clue_requests << {
              student_uuid: student_uuid,
              book_container_uuid: book_container_uuid,
              clue_data: clue_data
            }
          end
        end

        # Calculate teacher CLUes
        teacher_clue_requests = []
        teacher_clues_to_update.each do |book_container_uuid, course_container_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            Rails.logger.tagged('UpdateClues') do |logger|
              logger.warn do
                "Teacher CLUe skipped due to no information about book container #{
                  book_container_uuid
                }"
              end
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                     .compact
                                                                     .uniq

          course_container_uuids.uniq.each do |course_container_uuid|
            student_uuids = student_uuids_by_course_container_uuids[course_container_uuid]
            if student_uuids.nil?
              Rails.logger.tagged('UpdateClues') do |logger|
                logger.warn do
                  container_uuid = course_container_uuid

                  "Teacher CLUe skipped due to no information about course container #{
                    container_uuid
                  }"
                end
              end

              next
            end

            student_response_maps = responses_map.values_at(*student_uuids).compact
            clue_responses = student_response_maps.map do |student_response_map|
              student_response_map.values_at(*exercise_group_uuids)
            end.flatten.compact
            clue_data = calculate_clue_data(clue_responses).merge(ecosystem_uuid: ecosystem_uuid)

            teacher_clue_requests << {
              course_container_uuid: course_container_uuid,
              book_container_uuid: book_container_uuid,
              clue_data: clue_data
            }
          end
        end

        # Send CLUes to biglearn-api
        OpenStax::Biglearn::Api.update_student_clues student_clue_requests
        OpenStax::Biglearn::Api.update_teacher_clues teacher_clue_requests

        # Record the student CLUe values
        StudentClue.import student_clues, validate: false, on_duplicate_key_update: {
          conflict_target: [ :student_uuid, :book_container_uuid ],
          columns: [ :value ]
        }

        # Record the fact that the CLUes are up-to-date with the latest Responses
        response_clues = used_responses.map do |uuid, course_uuid|
          ResponseClue.new uuid: uuid, course_uuid: course_uuid
        end
        ResponseClue.import response_clues, validate: false, on_duplicate_key_ignore: {
          conflict_target: [ :uuid ]
        }

        # Mark relevant Students for PracticeWorstAreasExercises updates
        StudentPe.where(student_uuid: student_uuids_to_update_worst_areas_exercises).delete_all
        Student.where(uuid: student_uuids_to_update_worst_areas_exercises)
               .update_all(pes_are_assigned: false)

        responses.size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < BATCH_SIZE
    end

    Rails.logger.tagged 'UpdateClues' do |logger|
      logger.info do
        time = Time.now - start_time

        "Updated: #{total_responses} response(s) - Took: #{time} second(s)"
      end
    end
  end

  protected

  def calculate_clue_data(responses)
    if responses.size >= 3
      tot = responses.count
      suc = responses.count { |bool| !!bool }

      p_hat = (suc + 0.5*Z_ALPHA**2) / (tot + Z_ALPHA**2)

      var = responses.map { |bool| (p_hat - (bool ? 1 : 0))**2 }.reduce(&:+) / (tot - 1)

      interval = ( Z_ALPHA * Math.sqrt(p_hat*(1-p_hat)/(tot + Z_ALPHA**2)) +
                   0.1*Math.sqrt(var) + 0.05 )

      {
        minimum: [p_hat - interval, 0].max,
        most_likely: p_hat,
        maximum: [p_hat + interval, 1].min,
        is_real: true
      }
    else
      {
        minimum: 0,
        most_likely: 0.5,
        maximum: 1,
        is_real: false
      }
    end
  end
end

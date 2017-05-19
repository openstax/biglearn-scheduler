class Services::PrepareClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareClueCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    ee = EcosystemExercise.arel_table
    rsp = Response.arel_table

    # Do all the processing in batches to avoid OOM problems
    total_responses = 0
    loop do
      num_responses = Response.transaction do
        # Get Responses that have not yet been used in CLUes
        responses = Response.where(used_in_clue_calculations: false).take(BATCH_SIZE)

        # Build some hashes to minimize the number of queries

        # Map the students to courses and course containers
        student_uuids = responses.map(&:student_uuid)
        course_uuid_by_student_uuid = {}
        course_container_uuids_by_student_uuids = {}
        Student.where(uuid: student_uuids).each do |student|
          uuid = student.uuid
          course_uuid_by_student_uuid[uuid] = student.course_uuid
          course_container_uuids_by_student_uuids[uuid] = student.course_container_uuids
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
        used_response_uuids = []
        ee_queries = responses.map do |response|
          student_uuid = response.student_uuid
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]

          exercise_uuid = response.exercise_uuid
          exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]

          used_response_uuids << response.uuid

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

        trial_uuids = responses.map(&:trial_uuid)
        assignment_uuid_by_trial_uuid = AssignedExercise.where(uuid: trial_uuids)
                                                        .pluck(:uuid, :assignment_uuid)
                                                        .to_h

        # Collect ongoing assignment uuids so we can exclude them from the student CLUes
        ongoing_assignment_uuids = []
        Assignment.where(student_uuid: student_uuids)
                  .pluck(:uuid, :due_at, :opens_at)
                  .each do |assignment_uuid, due_at, opens_at|
          ongoing_assignment_uuids << assignment_uuid \
            if due_at.present? && due_at > start_time && (opens_at.nil? || opens_at < start_time)
        end

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
        student_responses_map = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        teacher_responses_map = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        Response.where(response_queries)
                .order(:responded_at)
                .pluck(:uuid, :trial_uuid, :student_uuid, :exercise_uuid, :is_correct)
                .each do |response_uuid, trial_uuid, student_uuid, exercise_uuid, is_correct|
          exercise_group_uuid = exercise_group_uuid_by_exercise_uuid[exercise_uuid]
          if exercise_group_uuid.nil?
            Rails.logger.tagged 'PrepareClueCalculations' do |logger|
              logger.warn do
                "Response skipped due to no information about exercise #{exercise_uuid}"
              end
            end

            next
          end

          assignment_uuid = assignment_uuid_by_trial_uuid[trial_uuid]
          response = {
            response_uuid: response_uuid,
            trial_uuid: trial_uuid,
            is_correct: is_correct
          }
          student_responses_map[student_uuid][exercise_group_uuid] << response \
            unless ongoing_assignment_uuids.include?(assignment_uuid)
          teacher_responses_map[student_uuid][exercise_group_uuid] << response

          course_uuid = course_uuid_by_student_uuid[student_uuid]
          used_response_uuids << response_uuid
        end unless response_queries.nil?

        # Calculate student CLUes
        student_clue_calculations =
          student_clues_to_update.flat_map do |book_container_uuid, student_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            Rails.logger.tagged 'PrepareClueCalculations' do |logger|
              logger.warn do
                "Student CLUe skipped due to no information about book container #{
                  book_container_uuid
                }"
              end
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          next if exercise_uuids.empty?

          exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                     .compact
                                                                     .uniq

          student_uuids.uniq.map do |student_uuid|
            responses_map = student_responses_map[student_uuid]
            responses = responses_map.values_at(*exercise_group_uuids).compact.flatten
            next if responses.empty?

            StudentClueCalculation.new(
              uuid: SecureRandom.uuid,
              ecosystem_uuid: ecosystem_uuid,
              book_container_uuid: book_container_uuid,
              student_uuid: student_uuid,
              exercise_uuids: exercise_uuids,
              responses: responses
            )
          end
        end.compact

        # Calculate teacher CLUes
        teacher_clue_calculations =
          teacher_clues_to_update.flat_map do |book_container_uuid, course_container_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            Rails.logger.tagged 'PrepareClueCalculations' do |logger|
              logger.warn do
                "Teacher CLUe skipped due to no information about book container #{
                  book_container_uuid
                }"
              end
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          next if exercise_uuids.empty?

          exercise_group_uuids = exercise_group_uuid_by_exercise_uuid.values_at(*exercise_uuids)
                                                                     .compact
                                                                     .uniq

          course_container_uuids.uniq.map do |course_container_uuid|
            student_uuids = student_uuids_by_course_container_uuids[course_container_uuid]
            if student_uuids.nil?
              Rails.logger.tagged 'PrepareClueCalculations' do |logger|
                logger.warn do
                  container_uuid = course_container_uuid

                  "Teacher CLUe skipped due to no information about course container #{
                    container_uuid
                  }"
                end
              end

              next
            end
            # Empty period
            next if student_uuids.empty?

            responses_maps = teacher_responses_map.values_at(*student_uuids).compact
            responses = responses_maps.map do |responses_map|
              responses_map.values_at(*exercise_group_uuids)
            end.flatten.compact
            next if responses.empty?

            TeacherClueCalculation.new(
              uuid: SecureRandom.uuid,
              ecosystem_uuid: ecosystem_uuid,
              book_container_uuid: book_container_uuid,
              course_container_uuid: course_container_uuid,
              student_uuids: student_uuids,
              exercise_uuids: exercise_uuids,
              responses: responses
            )
          end
        end.compact

        # Record the StudentClueCalculations
        student_clue_calc_ids = StudentClueCalculation.import(
          student_clue_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :student_uuid, :book_container_uuid ],
            columns: [ :exercise_uuids, :responses ]
          }
        ).ids

        # Delete existing AlgorithmStudentClueCalculations for affected StudentClueCalculations,
        # since they need to be recalculated
        student_clue_calculation_uuids = StudentClueCalculation.where(id: student_clue_calc_ids)
                                                               .pluck(:uuid)
        AlgorithmStudentClueCalculation
          .where(student_clue_calculation_uuid: student_clue_calculation_uuids)
          .delete_all

        # Record the TeacherClueCalculations
        teacher_clue_calc_ids = TeacherClueCalculation.import(
          teacher_clue_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :course_container_uuid, :book_container_uuid ],
            columns: [ :student_uuids, :exercise_uuids, :responses ]
          }
        ).ids

        # Delete existing AlgorithmTeacherClueCalculations for affected TeacherClueCalculations,
        # since they need to be recalculated
        teacher_clue_calculation_uuids = TeacherClueCalculation.where(id: teacher_clue_calc_ids)
                                                               .pluck(:uuid)
        AlgorithmTeacherClueCalculation
          .where(teacher_clue_calculation_uuid: teacher_clue_calculation_uuids)
          .delete_all

        # Record the fact that the CLUes are up-to-date with the latest Responses
        Response.where(uuid: used_response_uuids).update_all(used_in_clue_calculations: true)

        responses.size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareClueCalculations' do |logger|
      logger.debug do
        "#{total_responses} response(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end
end

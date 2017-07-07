class Services::PrepareClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 10

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    rr = Response.arel_table
    ex = Exercise.arel_table
    ee = EcosystemExercise.arel_table

    # Do all the processing in batches to avoid OOM problems
    total_responses = 0
    loop do
      # We use REPEATABLE READ isolation here to reduce useless work
      # if 2 workers happen to lock conflicting sets of responses
      # since we cannot use SKIP LOCKED in this case
      # The REPEATABLE READ isolation level will cause the second transaction to retry
      # once the first one releases the FOR UPDATE lock
      args = Response.connection.open_transactions == 0 ? { isolation: :repeatable_read } : {}
      num_responses = Response.transaction(args) do
        # Get Responses that have not yet been used in CLUes
        # Responses with no Exercise or AssignedExercise are completely ignored
        responses = Response.joins(:exercise, assigned_exercise: :assignment)
                            .where(used_in_clue_calculations: false)
                            .select([rr[Arel.star], ex[:group_uuid]])
                            .take(BATCH_SIZE)
        response_uuids = responses.map(&:uuid)

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
        student_uuids_by_course_container_uuids =
          CourseContainer.where(uuid: course_container_uuids)
                         .pluck(:uuid, :student_uuids)
                         .to_h

        # Map the courses to ecosystems
        course_uuids = course_uuid_by_student_uuid.values
        ecosystem_uuid_by_course_uuid = Course.where(uuid: course_uuids)
                                              .pluck(:uuid, :ecosystem_uuid)
                                              .to_h

        # Build a query to obtain the book_container_uuids for the new Responses
        ee_query = responses.map do |response|
          student_uuid = response.student_uuid
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]

          group_uuid = response.group_uuid

          ee[:ecosystem_uuid].eq(ecosystem_uuid).and ex[:group_uuid].eq(group_uuid)
        end.compact.reduce(:or)

        # Map the ecosystem_uuids and group_uuids to book_container_uuids
        book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        EcosystemExercise
          .with_group_uuids
          .where(ee_query)
          .pluck(:ecosystem_uuid, :group_uuid, :book_container_uuids)
          .each do |ecosystem_uuid, group_uuid, book_container_uuids|
          book_container_uuids_map[ecosystem_uuid][group_uuid] = book_container_uuids
        end unless ee_query.nil?

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

        # Get the group_uuids for the above exercise_uuids
        exercise_uuids = exercise_uuids_by_book_container_uuids.values.flatten
        group_uuids_by_exercise_uuids = Exercise.where(uuid: exercise_uuids)
                                                .pluck(:uuid, :group_uuid)
                                                .to_h

        # Create a map of group_uuids for each book_container_uuid
        group_uuids_by_book_container_uuids = {}
        exercise_uuids_by_book_container_uuids.each do |book_container_uuid, exercise_uuids|
          group_uuids = group_uuids_by_exercise_uuids.values_at(*exercise_uuids)
          group_uuids_by_book_container_uuids[book_container_uuid] = group_uuids
        end

        # Collect the CLUes that need to be updated and build the final Response query
        student_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
        teacher_clues_to_update = Hash.new { |hash, key| hash[key] = [] }
        response_query = responses.map do |response|
          student_uuid = response.student_uuid
          course_uuid = course_uuid_by_student_uuid[student_uuid]
          ecosystem_uuid = ecosystem_uuid_by_course_uuid[course_uuid]
          group_uuid = response.group_uuid

          # Find all book containers that contain the given exercise and all their exercises
          # exercise_group_uuid can be nil here...
          # this simply means the exercise was removed from the book and should not count for CLUes
          book_container_uuids = book_container_uuids_map[ecosystem_uuid].fetch group_uuid, []
          group_uuids = group_uuids_by_book_container_uuids.values_at(*book_container_uuids).flatten

          # Find all course containers that contain the given student
          course_container_uuids = course_container_uuids_by_student_uuids.fetch student_uuid, []

          book_container_uuids.each do |book_container_uuid|
            student_clues_to_update[book_container_uuid] << student_uuid

            teacher_clues_to_update[book_container_uuid].concat course_container_uuids
          end

          # All responses from students in the same course containers
          # that refer to any exercise in the same book containers should be considered
          student_uuids = student_uuids_by_course_container_uuids.values_at(*course_container_uuids)
                                                                 .flatten
          rr[:student_uuid].in(student_uuids).and ex[:group_uuid].in(group_uuids)
        end.compact.reduce(:or)

        # Map student_uuids and exercise_group_uuids to correctness information
        # Take only the latest answer for each exercise_group_uuid
        # Mark responses found here as used in CLUe calculations
        # Don't use SKIP LOCKED here because we need all responses that match the queries
        student_responses_map = Hash.new { |hash, key| hash[key] = {} }
        teacher_responses_map = Hash.new { |hash, key| hash[key] = {} }
        Response
          .joins(:exercise, assigned_exercise: :assignment)
          .where(response_query)
          .order(:last_responded_at)
          .lock('FOR UPDATE OF "responses"')
          .pluck(:uuid, :trial_uuid, :student_uuid, :used_in_clue_calculations,
                 :group_uuid, :is_correct, :feedback_at)
          .each do |response_uuid, trial_uuid, student_uuid, used_in_clue_calculations,
                    group_uuid, is_correct, feedback_at|
          response_uuids << response_uuid unless used_in_clue_calculations

          response_hash = {
            response_uuid: response_uuid,
            trial_uuid: trial_uuid,
            is_correct: is_correct
          }

          teacher_responses_map[student_uuid][group_uuid] = response_hash

          next unless feedback_at.nil? || feedback_at <= start_time

          student_responses_map[student_uuid][group_uuid] = response_hash
        end unless response_query.nil?

        # Calculate student CLUes
        student_clue_calculations =
          student_clues_to_update.flat_map do |book_container_uuid, student_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            log(:warn) do
              "Student CLUe skipped due to no information about book container #{
                book_container_uuid
              }"
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          next if exercise_uuids.empty?

          group_uuids = group_uuids_by_book_container_uuids[book_container_uuid]

          student_uuids.uniq.map do |student_uuid|
            responses_map = student_responses_map[student_uuid]
            response_hashes = responses_map.values_at(*group_uuids).compact
            next if responses.empty?

            StudentClueCalculation.new(
              uuid: SecureRandom.uuid,
              ecosystem_uuid: ecosystem_uuid,
              book_container_uuid: book_container_uuid,
              student_uuid: student_uuid,
              exercise_uuids: exercise_uuids,
              responses: response_hashes
            )
          end
        end.compact

        # Calculate teacher CLUes
        teacher_clue_calculations =
          teacher_clues_to_update.flat_map do |book_container_uuid, course_container_uuids|
          ecosystem_uuid = ecosystem_uuid_by_book_container_uuid[book_container_uuid]
          if ecosystem_uuid.nil?
            log(:warn) do
              "Teacher CLUe skipped due to no information about book container #{
                book_container_uuid
              }"
            end

            next
          end

          exercise_uuids = exercise_uuids_by_book_container_uuids[book_container_uuid]
          next if exercise_uuids.empty?

          group_uuids = group_uuids_by_book_container_uuids[book_container_uuid]

          course_container_uuids.uniq.map do |course_container_uuid|
            student_uuids = student_uuids_by_course_container_uuids[course_container_uuid]
            if student_uuids.nil?
              log(:warn) do
                container_uuid = course_container_uuid

                "Teacher CLUe skipped due to no information about course container #{
                  container_uuid
                }"
              end

              next
            end
            # Empty period
            next if student_uuids.empty?

            responses_maps = teacher_responses_map.values_at(*student_uuids).compact
            response_hashes = responses_maps.flat_map do |responses_map|
              responses_map.values_at(*group_uuids)
            end.compact
            next if response_hashes.empty?

            TeacherClueCalculation.new(
              uuid: SecureRandom.uuid,
              ecosystem_uuid: ecosystem_uuid,
              book_container_uuid: book_container_uuid,
              course_container_uuid: course_container_uuid,
              student_uuids: student_uuids,
              exercise_uuids: exercise_uuids,
              responses: response_hashes
            )
          end
        end.compact

        # Record the StudentClueCalculations
        StudentClueCalculation.import(
          student_clue_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :student_uuid, :book_container_uuid ],
            columns: [ :uuid, :exercise_uuids, :responses ]
          }
        )

        # Cleanup AlgorithmStudentClueCalculations that no longer have
        # an associated StudentClueCalculation record
        AlgorithmStudentClueCalculation.unassociated.delete_all

        # Record the TeacherClueCalculations
        TeacherClueCalculation.import(
          teacher_clue_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :course_container_uuid, :book_container_uuid ],
            columns: [ :uuid, :student_uuids, :exercise_uuids, :responses ]
          }
        )

        # Cleanup AlgorithmTeacherClueCalculations that no longer have
        # an associated TeacherClueCalculation record
        AlgorithmTeacherClueCalculation.unassociated.delete_all

        # Record the fact that the CLUes are up-to-date with the latest Responses
        Response.where(uuid: response_uuids).update_all(used_in_clue_calculations: true)

        responses.size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end

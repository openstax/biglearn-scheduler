class Services::PrepareClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 10
  MAX_RETRIES = 3
  RETRY_DELAY = 1

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    scc = StudentClueCalculation.arel_table

    total_responses = 0
    total_sccs = 0
    loop do
      retries = 0
      num_responses, num_sccs = begin
        Response.transaction do
          # Get Responses that have not yet been used in CLUes
          # Responses with no AssignedExercise or Assignment are completely ignored
          responses = Response.joins(assigned_exercise: :assignment)
                              .where(used_in_clue_calculations: false)
                              .lock('FOR NO KEY UPDATE OF "responses" SKIP LOCKED')
                              .take(BATCH_SIZE)
          # Also get any StudentClueCalculations that need to be recalculated
          sccs = StudentClueCalculation
            .where(scc[:recalculate_at].lteq(start_time))
            .lock('FOR UPDATE SKIP LOCKED')
            .take(BATCH_SIZE)
          next [ 0, 0 ] if responses.empty? && sccs.empty?

          response_uuids = responses.map(&:uuid)
          responses_by_ecosystem_uuid = responses.group_by(&:ecosystem_uuid)
          scc_uuids = sccs.map(&:uuid)
          student_uuids = (responses + sccs).map(&:student_uuid)
          sccs_by_ecosystem_uuid = sccs.group_by(&:ecosystem_uuid)

          # Map the students to courses and course containers (for teacher CLUes)
          course_uuid_by_student_uuid = {}
          course_container_uuids_by_student_uuids = {}
          Student.where(uuid: student_uuids).each do |student|
            uuid = student.uuid
            course_uuid_by_student_uuid[uuid] = student.course_uuid
            course_container_uuids_by_student_uuids[uuid] = student.course_container_uuids
          end

          # Map the course containers back to students (for teacher CLUes)
          course_container_uuids = course_container_uuids_by_student_uuids.values.flatten
          student_uuids_by_course_container_uuids =
            CourseContainer.where(uuid: course_container_uuids)
                           .pluck(:uuid, :student_uuids)
                           .to_h

          from_book_container_uuids_map = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end

          # Obtain the book_container_uuids for the Responses and StudentClueCalculations
          response_ecosystem_exercises = EcosystemExercise
            .joins(:responses)
            .where(responses: { uuid: response_uuids })
            .pluck(:ecosystem_uuid, :exercise_uuid, :book_container_uuids)
          scc_ecosystem_exercises = EcosystemExercise
            .joins(:student_clue_calculations)
            .where(student_clue_calculations: { uuid: scc_uuids })
            .pluck(:ecosystem_uuid, :exercise_uuid, :book_container_uuids)
          ecosystem_exercises = response_ecosystem_exercises + scc_ecosystem_exercises

          ecosystem_exercises.each do |ecosystem_uuid, exercise_uuid, book_container_uuids|
            from_book_container_uuids_map[ecosystem_uuid][exercise_uuid] = book_container_uuids
          end

          # Also add the book_container_uuids for the grouped StudentClueCalculations to the map
          sccs.each do |scc|
            ecosystem_uuid = scc.ecosystem_uuid
            exercise_uuids = scc.exercise_uuids
            book_container_uuid = scc.book_container_uuid

            exercise_uuids.each do |exercise_uuid|
              from_book_container_uuids_map[ecosystem_uuid][exercise_uuid] << book_container_uuid
            end
          end

          # Map the courses to latest ecosystems
          course_uuids = course_uuid_by_student_uuid.values
          latest_ecosystem_uuid_by_course_uuid = Course.where(uuid: course_uuids)
                                                       .pluck(:uuid, :ecosystem_uuid)
                                                       .to_h

          # Create queries to map the book_container_uuids to
          # book_container_uuids in the courses' latest ecosystems
          forward_mappings = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = {} }
          end
          forward_mapping_values_array = responses_by_ecosystem_uuid
            .flat_map do |from_ecosystem_uuid, responses|
            from_eco_book_container_uuids_map = from_book_container_uuids_map[from_ecosystem_uuid]

            responses.map do |response|
              student_uuid = response.student_uuid
              course_uuid = course_uuid_by_student_uuid[student_uuid]
              to_ecosystem_uuid = latest_ecosystem_uuid_by_course_uuid[course_uuid]
              next if to_ecosystem_uuid.nil? || to_ecosystem_uuid == from_ecosystem_uuid

              exercise_uuid = response.exercise_uuid
              from_book_container_uuids = from_eco_book_container_uuids_map[exercise_uuid]

              [ from_ecosystem_uuid, to_ecosystem_uuid, from_book_container_uuids ]
            end.compact
          end + sccs_by_ecosystem_uuid.flat_map do |from_ecosystem_uuid, sccs|
            from_eco_book_container_uuids_map =
              from_book_container_uuids_map[from_ecosystem_uuid]

            sccs.map do |scc|
              course_uuid = course_uuid_by_student_uuid[scc.student_uuid]
              to_ecosystem_uuid = latest_ecosystem_uuid_by_course_uuid[course_uuid]
              next if to_ecosystem_uuid.nil? || to_ecosystem_uuid == from_ecosystem_uuid

              [ from_ecosystem_uuid, to_ecosystem_uuid, [ scc.book_container_uuid ] ]
            end.compact
          end
          unless forward_mapping_values_array.empty?
            forward_mapping_join_query = <<-JOIN_SQL.strip_heredoc
              INNER JOIN (#{ValuesTable.new(forward_mapping_values_array)}) AS "values"
                ("from_ecosystem_uuid", "to_ecosystem_uuid", "from_book_container_uuids")
                ON "book_container_mappings"."from_ecosystem_uuid" = "values"."from_ecosystem_uuid"
                  AND "book_container_mappings"."to_ecosystem_uuid" = "values"."to_ecosystem_uuid"
                  AND "book_container_mappings"."from_book_container_uuid" =
                    ANY("values"."from_book_container_uuids")
            JOIN_SQL
            BookContainerMapping.joins(forward_mapping_join_query)
                                .pluck(
                                  :from_ecosystem_uuid,
                                  :from_book_container_uuid,
                                  :to_ecosystem_uuid,
                                  :to_book_container_uuid
                                ).each do |
                                  from_ecosystem_uuid,
                                  from_book_container_uuid,
                                  to_ecosystem_uuid,
                                  to_book_container_uuid
                                |
              forward_mappings[from_ecosystem_uuid][from_book_container_uuid][to_ecosystem_uuid] =
                to_book_container_uuid
            end
          end

          # Collect all the CLUes to update from the forward mapping of the Responses
          student_clues_to_update = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
          teacher_clues_to_update = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
          responses_by_ecosystem_uuid.each do |from_ecosystem_uuid, responses|
            from_ecosystem_mappings = forward_mappings[from_ecosystem_uuid]

            responses.map do |response|
              student_uuid = response.student_uuid
              exercise_uuid = response.exercise_uuid

              # Find all course containers that contain the given student
              course_container_uuids = course_container_uuids_by_student_uuids.fetch(
                student_uuid, []
              )

              # Teacher clues use all students in the same course container
              student_uuids = student_uuids_by_course_container_uuids
                .values_at(*course_container_uuids).compact.flatten

              # Find which is the response's book_container_uuid
              # and which ecosystem it must map to
              course_uuid = course_uuid_by_student_uuid[student_uuid]
              to_ecosystem_uuid = latest_ecosystem_uuid_by_course_uuid[course_uuid]
              from_book_container_uuids =
                from_book_container_uuids_map[from_ecosystem_uuid][exercise_uuid]

              # Forward map the response to find which book_container_uuid it maps to
              to_book_container_uuids = from_book_container_uuids.map do |from_book_container_uuid|
                from_ecosystem_mappings[from_book_container_uuid].fetch(
                  to_ecosystem_uuid, from_book_container_uuid
                )
              end

              # We will update the student and teacher CLUes
              # for which the responses above are relevant
              to_book_container_uuids.each do |to_book_container_uuid|
                student_clues_to_update[to_ecosystem_uuid][to_book_container_uuid] << student_uuid
                teacher_clues_to_update[to_ecosystem_uuid][to_book_container_uuid].concat(
                  course_container_uuids
                )
              end
            end
          end

          # Also add the StudentClueCalculations that need to be recalculated to the list
          sccs_by_ecosystem_uuid.each do |from_ecosystem_uuid, scc|
            from_ecosystem_mappings = forward_mappings[from_ecosystem_uuid]

            sccs.each do |scc|
              # Find the student's course and its latest ecosystem
              student_uuid = scc.student_uuid
              course_uuid = course_uuid_by_student_uuid[student_uuid]
              to_ecosystem_uuid = latest_ecosystem_uuid_by_course_uuid[course_uuid]

              # Forward map the from_book_container_uuid to find the to_book_container_uuid
              from_book_container_uuid = scc.book_container_uuid
              to_book_container_uuid = from_ecosystem_mappings[from_book_container_uuid].fetch(
                to_ecosystem_uuid, from_book_container_uuid
              )

              # Add it to the list of CLUes to update
              student_clues_to_update[to_ecosystem_uuid][to_book_container_uuid] << student_uuid
            end
          end

          # Find all book_container_uuids that map to the book_container_uuids found above
          reverse_mappings = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = {} }
          end
          unless student_clues_to_update.empty?
            reverse_mapping_values_array = student_clues_to_update
              .flat_map do |to_ecosystem_uuid, book_container_student_clues|
              book_container_student_clues.keys.map do |to_book_container_uuid|
                [ to_ecosystem_uuid, to_book_container_uuid ]
              end
            end
            reverse_mapping_join_query = <<-JOIN_SQL.strip_heredoc
              INNER JOIN (#{ValuesTable.new(reverse_mapping_values_array)})
                AS "values" ("to_ecosystem_uuid", "to_book_container_uuid")
                ON "book_container_mappings"."to_ecosystem_uuid" = "values"."to_ecosystem_uuid"
                  AND "book_container_mappings"."to_book_container_uuid" =
                    "values"."to_book_container_uuid"
            JOIN_SQL
            BookContainerMapping.joins(reverse_mapping_join_query)
                                .pluck(
                                  :to_ecosystem_uuid,
                                  :to_book_container_uuid,
                                  :from_ecosystem_uuid,
                                  :from_book_container_uuid
                                ).each do |
                                  to_ecosystem_uuid,
                                  to_book_container_uuid,
                                  from_ecosystem_uuid,
                                  from_book_container_uuid
                                |
              reverse_mappings[to_ecosystem_uuid][to_book_container_uuid][from_ecosystem_uuid] =
                from_book_container_uuid
            end
          end

          # Map the found book_container_uuids to exercise_uuids that should be used for CLUes
          from_book_container_uuids = reverse_mappings.values.map do |val|
            val.values.map(&:values)
          end.flatten + from_book_container_uuids_map.values.map(&:values).flatten
          clue_exercise_uuids_by_book_container_uuids = Hash.new { |hash, key| hash[key] = [] }
          ExercisePool.where(book_container_uuid: from_book_container_uuids, use_for_clue: true)
                      .pluck(:book_container_uuid, :exercise_uuids)
                      .each do |book_container_uuid, exercise_uuids|
            clue_exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
          end

          # Map the exercise_uuids above to group_uuids
          all_exercise_uuids = clue_exercise_uuids_by_book_container_uuids.values.flatten
          exercise_group_uuids_by_exercise_uuids = Exercise.where(uuid: all_exercise_uuids)
                                                           .pluck(:uuid, :group_uuid)
                                                           .to_h

          # Build the final Response query
          response_values_array = student_clues_to_update
            .flat_map do |to_ecosystem_uuid, to_ecosystem_student_clues|
            to_ecosystem_student_clues.map do |to_book_container_uuid, student_uuids|
              # Reverse map to find book_container_uuids that map to the to_book_container_uuid
              same_mapping_book_container_uuids = [ to_book_container_uuid ] +
                reverse_mappings[to_ecosystem_uuid][to_book_container_uuid].values

              # Find all exercises in the above book_container_uuids
              exercise_uuids = clue_exercise_uuids_by_book_container_uuids
                .values_at(*same_mapping_book_container_uuids).flatten

              # Load all responses from the students
              # that refer to any exercise in the same_mapping_book_container_uuids
              [ student_uuids, exercise_uuids ]
            end
          end + teacher_clues_to_update
            .flat_map do |to_ecosystem_uuid, to_ecosystem_teacher_clues|
            to_ecosystem_teacher_clues.map do |to_book_container_uuid, course_container_uuids|
              # Reverse map to find book_container_uuids that map to the to_book_container_uuid
              same_mapping_book_container_uuids = [ to_book_container_uuid ] +
                reverse_mappings[to_ecosystem_uuid][to_book_container_uuid].values

              # Find all exercises in the above book_container_uuids
              exercise_uuids = clue_exercise_uuids_by_book_container_uuids
                .values_at(*same_mapping_book_container_uuids).flatten

              # Teacher clues use all students in the same course container
              student_uuids = student_uuids_by_course_container_uuids
                .values_at(*course_container_uuids).compact.flatten

              # Load all responses from students in the same course containers
              # that refer to any exercise in the same_mapping_book_container_uuids
              [ student_uuids, exercise_uuids ]
            end
          end

          # Map student_uuids and exercise_group_uuids to correctness information
          # Take only the latest answer for each exercise_group_uuid
          # Mark responses found here as used in CLUe calculations
          # Don't use SKIP LOCKED here because we need all responses that match the queries
          student_responses_map = Hash.new { |hash, key| hash[key] = {} }
          student_recalculate_ats_map = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
          teacher_responses_map = Hash.new { |hash, key| hash[key] = {} }
          unless response_values_array.empty?
            response_join_query = <<-JOIN_SQL.strip_heredoc
              INNER JOIN (#{ValuesTable.new(response_values_array)})
                AS "values" ("student_uuids", "exercise_uuids")
              ON "responses"."student_uuid" = ANY ("values"."student_uuids")
                AND "responses"."exercise_uuid" = ANY ("values"."exercise_uuids")
            JOIN_SQL
            Response
              .joins(assigned_exercise: :assignment)
              .joins(response_join_query)
              .order(:last_responded_at)
              .lock('FOR NO KEY UPDATE OF "responses" NOWAIT')
              .pluck(:uuid, :trial_uuid, :student_uuid, :exercise_uuid,
                     :used_in_clue_calculations, :is_correct, :feedback_at)
              .each do |response_uuid, trial_uuid, student_uuid, exercise_uuid,
                        used_in_clue_calculations, is_correct, feedback_at|
              response_uuids << response_uuid unless used_in_clue_calculations

              # We can safely skip Responses whose exercise_uuid is absent from this hash
              # Because that means their exercises only appear in pools not used for CLUes
              group_uuid = exercise_group_uuids_by_exercise_uuids[exercise_uuid]
              next if group_uuid.nil?

              response_hash = {
                response_uuid: response_uuid,
                trial_uuid: trial_uuid,
                is_correct: is_correct
              }

              teacher_responses_map[student_uuid][group_uuid] = response_hash

              if feedback_at.nil? || feedback_at <= start_time
                student_responses_map[student_uuid][group_uuid] = response_hash
              else
                student_recalculate_ats_map[student_uuid][group_uuid] << feedback_at
              end
            end
          end

          # Calculate student CLUes
          student_clue_calculations = student_clues_to_update
            .flat_map do |ecosystem_uuid, ecosystem_student_clues_to_update|
            ecosystem_student_clues_to_update.flat_map do |book_container_uuid, student_uuids|
              from_book_container_uuids = [ book_container_uuid ] +
                reverse_mappings[ecosystem_uuid][book_container_uuid].values
              exercise_uuids = clue_exercise_uuids_by_book_container_uuids
                .values_at(*from_book_container_uuids).flatten.uniq
              group_uuids = exercise_group_uuids_by_exercise_uuids.values_at(*exercise_uuids)
                                                                  .compact
                                                                  .uniq
              next [] if group_uuids.empty?

              student_uuids.uniq.map do |student_uuid|
                responses_map = student_responses_map[student_uuid]
                response_hashes = responses_map.values_at(*group_uuids).compact
                recalculate_at = student_recalculate_ats_map[student_uuid]
                  .values_at(*group_uuids).flatten.min
                next if response_hashes.empty? && recalculate_at.nil?

                StudentClueCalculation.new(
                  uuid: SecureRandom.uuid,
                  ecosystem_uuid: ecosystem_uuid,
                  book_container_uuid: book_container_uuid,
                  student_uuid: student_uuid,
                  exercise_uuids: exercise_uuids,
                  responses: response_hashes,
                  recalculate_at: recalculate_at
                )
              end.compact
            end
          end

          # Calculate teacher CLUes
          teacher_clue_calculations = teacher_clues_to_update
            .flat_map do |ecosystem_uuid, ecosystem_teacher_clues_to_update|
            ecosystem_teacher_clues_to_update
              .flat_map do |book_container_uuid, course_container_uuids|
              from_book_container_uuids = [ book_container_uuid ] +
                reverse_mappings[ecosystem_uuid][book_container_uuid].values
              exercise_uuids = clue_exercise_uuids_by_book_container_uuids
                .values_at(*from_book_container_uuids).flatten.uniq
              group_uuids = exercise_group_uuids_by_exercise_uuids.values_at(*exercise_uuids)
                                                                  .compact
                                                                  .uniq
              next [] if group_uuids.empty?

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
              end.compact
            end
          end

          # Record the StudentClueCalculations
          StudentClueCalculation.import(
            student_clue_calculations, validate: false, on_duplicate_key_update: {
              conflict_target: [ :student_uuid, :book_container_uuid ],
              columns: [ :uuid, :exercise_uuids, :responses, :recalculate_at, :algorithm_names ]
            }
          )

          # Any StudentClueCalculations that did not get updated (still have the same UUID)
          # have their recalculate_ats cleared
          # Just so we don't keep retrying to update StudentClueCalculations that will never succeed
          # (for example, due to an Ecosystem update)
          StudentClueCalculation.where(uuid: scc_uuids).update_all(recalculate_at: nil)

          # Cleanup AlgorithmStudentClueCalculations that no longer have
          # an associated StudentClueCalculation record
          AlgorithmStudentClueCalculation.unassociated.delete_all

          # Record the TeacherClueCalculations
          TeacherClueCalculation.import(
            teacher_clue_calculations, validate: false, on_duplicate_key_update: {
              conflict_target: [ :course_container_uuid, :book_container_uuid ],
              columns: [ :uuid, :student_uuids, :exercise_uuids, :responses, :algorithm_names ]
            }
          )

          # Cleanup AlgorithmTeacherClueCalculations that no longer have
          # an associated TeacherClueCalculation record
          AlgorithmTeacherClueCalculation.unassociated.delete_all

          # Record the fact that the CLUes are up-to-date with the latest Responses
          Response.where(uuid: response_uuids).update_all(used_in_clue_calculations: true)

          [ responses.size, sccs.size ]
        end
      rescue ActiveRecord::StatementInvalid => exception
        raise exception if !exception.cause.is_a?(PG::LockNotAvailable) || retries >= MAX_RETRIES

        retries += 1
        log(:warn) { "#{exception.message.split("\n:").first}. Retry ##{retries}..." }
        sleep(RETRY_DELAY)
        retry
      end

      total_responses += num_responses
      total_sccs += num_sccs
      # If we got less responses and sccs than the batch size, then this is the last batch
      break if num_responses < BATCH_SIZE && num_sccs < BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s) processed and #{total_sccs
      } student CLUe(s) recalculated in #{Time.current - start_time} second(s)"
    end
  end
end

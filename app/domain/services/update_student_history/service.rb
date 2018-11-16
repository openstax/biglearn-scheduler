class Services::UpdateStudentHistory::Service < Services::ApplicationService
  BATCH_SIZE = 100

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    # Check new responses and add assignments that have been completed to the student history
    total_responses = 0
    total_completed_assignments = 0
    loop do
      num_responses = Response.transaction do
        # Find responses not yet used in the student history
        # No order needed because of SKIP LOCKED
        responses = Response
          .select(:uuid, :assignment_uuid)
          .joins(assigned_exercise: :assignment)
          .where(used_in_student_history: false)
          .lock('FOR NO KEY UPDATE OF "responses", "assignments" SKIP LOCKED')
          .take(BATCH_SIZE)
        responses_size = responses.size
        next 0 if responses_size == 0

        # Mark the above responses as used in the student history
        response_uuids = responses.map(&:uuid)
        # No order needed because already locked above
        Response.where(uuid: response_uuids).update_all(used_in_student_history: true)

        # Find assignments that correspond to the above responses and check if they are complete
        # No order needed because already locked above
        responded_assignment_uuids = responses.map(&:assignment_uuid)
        completed_assignments = Assignment
          .select(:uuid, :student_uuid)
          .where(uuid: responded_assignment_uuids, student_history_at: nil)
          .where(
            <<-WHERE_SQL.strip_heredoc
              NOT EXISTS (
                SELECT *
                  FROM "assigned_exercises"
                  WHERE "assigned_exercises"."assignment_uuid" = "assignments"."uuid"
                    AND "assigned_exercises"."is_spe" = FALSE
                    AND NOT EXISTS (
                      SELECT *
                        FROM "responses"
                        WHERE "responses"."trial_uuid" = "assigned_exercises"."uuid"
                          AND "responses"."first_responded_at" <= "assignments"."due_at"
                    )
              )
            WHERE_SQL
          )
          .to_a
        next num_responses if completed_assignments.empty?

        total_completed_assignments += completed_assignments.size

        # Add the completed assignments to the student history
        completed_assignment_uuids = completed_assignments.map(&:uuid)
        # No order needed because already locked above
        Assignment.where(uuid: completed_assignment_uuids).update_all(
          <<-SQL.strip_heredoc
            "student_history_at" = (
              SELECT MAX("responses"."first_responded_at")
                FROM "assigned_exercises"
                  INNER JOIN "responses"
                    ON "responses"."trial_uuid" = "assigned_exercises"."uuid"
                WHERE "assigned_exercises"."assignment_uuid" = "assignments"."uuid"
                  AND "assigned_exercises"."is_spe" = FALSE
                  AND "responses"."first_responded_at" <= "assignments"."due_at"
                GROUP BY "assigned_exercises"."assignment_uuid"
            )
          SQL
        )

        # Recalculate all SPEs for affected students
        AlgorithmExerciseCalculation
          .joins(exercise_calculation: :assignments)
          .where(assignments: { student_uuid: completed_assignments.map(&:student_uuid) })
          .ordered_update_all(is_uploaded_for_assignment_uuids: [])

        responses_size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < BATCH_SIZE
    end

    aa = Assignment.arel_table

    # Add past-due assignments to the student history
    total_due_assignments = 0
    loop do
      num_due_assignments = Assignment.transaction do
        # Postgres < 10 cannot properly handle correlated columns
        # (such as due_at and student_history_at)
        # So we disable sequential scans for this query
        Assignment.connection.execute 'SET LOCAL enable_seqscan = OFF'

        # No order needed because of SKIP LOCKED
        due_assignments = Assignment
          .select(:uuid, :student_uuid)
          .where(student_history_at: nil)
          .where(aa[:due_at].lteq(start_time))
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .take(BATCH_SIZE)
        due_assignments_size = due_assignments.size
        next 0 if due_assignments_size == 0

        Assignment.connection.execute 'SET LOCAL enable_seqscan = ON'

        due_assignment_uuids = due_assignments.map(&:uuid)
        # No order needed because already locked above
        Assignment.where(uuid: due_assignment_uuids).update_all('"student_history_at" = "due_at"')

        # Recalculate all SPEs for affected students
        AlgorithmExerciseCalculation
          .joins(exercise_calculation: :assignments)
          .where(assignments: { student_uuid: due_assignments.map(&:student_uuid) })
          .ordered_update_all(is_uploaded_for_assignment_uuids: [])

        due_assignments_size
      end

      # If we got less assignments than the batch size, then this is the last batch
      total_due_assignments += num_due_assignments
      break if num_due_assignments < BATCH_SIZE
    end

    log(:debug) do
      total_assignments = total_completed_assignments + total_due_assignments

      "#{total_responses} response(s) and #{total_assignments} assignment(s) (#{
      total_completed_assignments} completed and #{total_due_assignments
      } past-due) processed in #{Time.current - start_time} second(s)"
    end
  end
end

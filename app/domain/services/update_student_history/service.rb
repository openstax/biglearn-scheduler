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
          .where(is_used_in_student_history: false)
          .lock('FOR NO KEY UPDATE OF "responses", "assignments" SKIP LOCKED')
          .take(BATCH_SIZE)
        responses_size = responses.size
        next 0 if responses_size == 0

        # Mark the above responses as used in the student history
        response_uuids = responses.map(&:uuid)
        # No order needed because already locked above
        Response.where(uuid: response_uuids).update_all(is_used_in_student_history: true)

        # Find assignments that correspond to the above responses and check if they are complete
        # No order needed because already locked above
        responded_assignment_uuids = responses.map(&:assignment_uuid)
        completed_assignments = Assignment
          .select(:uuid, :student_uuid)
          .where(uuid: responded_assignment_uuids, student_history_at: nil)
          .where(
            <<~WHERE_SQL
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
        next responses_size if completed_assignments.empty?

        total_completed_assignments += completed_assignments.size

        # Add the completed assignments to the student history
        completed_assignment_uuids = completed_assignments.map(&:uuid)
        # No order needed because already locked above
        Assignment.where(uuid: completed_assignment_uuids).update_all(
          <<~SQL
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
        reset_pending_assignment_uuids_for_student_uuids completed_assignments.map(&:student_uuid)

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
        reset_pending_assignment_uuids_for_student_uuids due_assignments.map(&:student_uuid)

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

  protected

  def reset_pending_assignment_uuids_for_student_uuids(student_uuids)
    # The ExerciseCalculation lock ensures we don't miss updates on
    # concurrent Assignment and AlgorithmExerciseCalculation inserts
    exercise_calculation_uuids = ExerciseCalculation
      .joins(:assignments)
      .not_superseded
      .where(assignments: { student_uuid: student_uuids })
      .ordered
      .lock('FOR NO KEY UPDATE OF "exercise_calculations"')
      .pluck(:uuid)
      .uniq

    assignment_uuids_by_exercise_calculation_uuid = Hash.new { |hash, key| hash[key] = [] }
    Assignment
      .joins(:exercise_calculation)
      .where(exercise_calculations: { uuid: exercise_calculation_uuids })
      .pluck(ExerciseCalculation.arel_table[:uuid], :uuid)
      .each do |exercise_calculation_uuid, uuid|
        assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid] << uuid
      end

    algorithm_exercise_calculations = AlgorithmExerciseCalculation
      .where(exercise_calculation_uuid: exercise_calculation_uuids)
      .to_a

    algorithm_exercise_calculations.each do |algorithm_exercise_calculation|
      calculation_uuid = algorithm_exercise_calculation.exercise_calculation_uuid
      assignment_uuids = assignment_uuids_by_exercise_calculation_uuid[calculation_uuid]
      algorithm_exercise_calculation.pending_assignment_uuids = assignment_uuids
    end

    AlgorithmExerciseCalculation.import(
      algorithm_exercise_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ], columns: [ :pending_assignment_uuids ]
      }
    )
  end
end

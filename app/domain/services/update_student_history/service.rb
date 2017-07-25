class Services::UpdateStudentHistory::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    total_completed_assignments = 0
    total_due_assignments = 0
    loop do
      num_completed_assignments = Assignment.transaction do
        completed_assignments = Assignment
          .select(:uuid, :student_uuid)
          .where(student_history_at: nil)
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
          .limit(BATCH_SIZE)
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .to_a

        next 0 if completed_assignments.empty?

        completed_assignment_uuids = completed_assignments.map(&:uuid)
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

        completed_assignment_student_uuids = completed_assignments.map(&:student_uuid)
        AssignmentSpe.joins(:assignment)
                     .where(assignments: { student_uuid: completed_assignment_student_uuids })
                     .delete_all

        completed_assignments.size
      end

      total_completed_assignments += num_completed_assignments
      break if num_completed_assignments < BATCH_SIZE
    end

    loop do
      num_due_assignments = Assignment.transaction do
        due_assignments = Assignment
          .select(:uuid, :student_uuid)
          .where(student_history_at: nil)
          .where("\"due_at\" <= '#{start_time.to_s(:db)}'")
          .limit(BATCH_SIZE)
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .to_a

        next 0 if due_assignments.empty?

        due_assignment_uuids = due_assignments.map(&:uuid)
        Assignment.where(uuid: due_assignment_uuids).update_all('"student_history_at" = "due_at"')

        due_assignment_student_uuids = due_assignments.map(&:student_uuid)
        AssignmentSpe.joins(:assignment)
                     .where(assignments: { student_uuid: due_assignment_student_uuids })
                     .delete_all

        due_assignments.size
      end

      total_due_assignments += num_due_assignments
      break if num_due_assignments < BATCH_SIZE
    end

    log(:debug) do
      total_assignments = total_completed_assignments + total_due_assignments

      "#{total_assignments} assignment(s) (#{total_completed_assignments} completed and #{
      total_due_assignments} past due) added to the student history in #{
      Time.current - start_time} second(s)"
    end
  end
end

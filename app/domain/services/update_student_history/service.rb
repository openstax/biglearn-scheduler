class Services::UpdateStudentHistory::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    num_assignments = Assignment.transaction do
      assignment_uuids = Assignment.where(student_history_at: nil)
                                   .where.not(due_at: nil)
                                   .lock('FOR NO KEY UPDATE SKIP LOCKED')
                                   .pluck(:uuid)

      next 0 if assignment_uuids.empty?

      student_uuids = Assignment.connection.execute(
        <<-SQL.strip_heredoc
          UPDATE "assignments" SET "student_history_at" = (
            SELECT CASE
              WHEN EVERY("responses"."id" IS NOT NULL)
                THEN MAX("responses"."first_responded_at")
              WHEN "assignments"."due_at" <= '#{start_time.to_s(:db)}'
                THEN "assignments"."due_at"
              END AS "student_history_at"
            FROM "assigned_exercises"
              LEFT OUTER JOIN "responses"
                ON "responses"."trial_uuid" = "assigned_exercises"."uuid"
                  AND "responses"."first_responded_at" <= "assignments"."due_at"
            WHERE "assigned_exercises"."assignment_uuid" = "assignments"."uuid"
              AND "assigned_exercises"."is_spe" = FALSE
            GROUP BY "assigned_exercises"."assignment_uuid"
          )
          WHERE "assignments"."uuid" IN (#{assignment_uuids.map { |uuid| "'#{uuid}'" }.join(', ')})
          RETURNING "assignments"."student_uuid", "assignments"."student_history_at"
        SQL
      ).reject { |row| row['student_history_at'].nil? }.map { |row| row['student_uuid'] }

      AssignmentSpe.joins(:assignment)
                   .where(assignments: { student_uuid: student_uuids })
                   .delete_all

      student_uuids.size
    end

    log(:debug) do
      "#{num_assignments} assignment(s) added to the student history in #{
      Time.current - start_time} second(s)"
    end
  end
end
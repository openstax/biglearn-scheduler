class Services::UpdateStudentHistory::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

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
        WHERE "assignments"."due_at" IS NOT NULL
          AND "assignments"."student_history_at" IS NULL
        RETURNING "assignments"."student_uuid", "assignments"."student_history_at"
      SQL
    ).reject { |row| row['student_history_at'].nil? }.map { |row| row['student_uuid'] }

    AssignmentSpe.joins(:assignment).where(assignments: { student_uuid: student_uuids }).delete_all

    num_assignments = student_uuids.size

    log(:debug) do
      "#{num_assignments} assignment(s) added to the student history in #{
      Time.current - start_time} second(s)"
    end
  end
end

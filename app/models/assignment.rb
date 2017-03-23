class Assignment < ApplicationRecord
  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  # TODO: student_driven_sequence_number
  scope :with_instructor_and_student_driven_sequence_numbers, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT assignments.*,
            row_number() OVER (
              PARTITION by assignments.student_uuid, assignments.assignment_type
              ORDER BY assignments.due_at ASC, assignments.opens_at ASC, assignments.created_at ASC
            ) AS instructor_driven_sequence_number,
            row_number() OVER (
              PARTITION by assignments.student_uuid, assignments.assignment_type
              ORDER BY assignment_core_steps_completion.core_steps_completed_at ASC
            ) AS student_driven_sequence_number
          FROM assignments
          LEFT OUTER JOIN (
            SELECT assigned_exercises.assignment_uuid,
              MAX(responses.responded_at) AS core_steps_completed_at
            FROM assigned_exercises
            LEFT OUTER JOIN responses
              ON responses.uuid = assigned_exercises.uuid
            WHERE assigned_exercises.is_spe = FALSE
              AND assigned_exercises.is_pe = FALSE
            GROUP BY assigned_exercises.assignment_uuid
            HAVING COUNT(assigned_exercises.uuid) = COUNT(responses.uuid)
          ) AS assignment_core_steps_completion
            ON assignment_core_steps_completion.assignment_uuid = assignments.uuid
        ) AS assignments
      SQL
    )
  end

  validates :course_uuid,     presence: true
  validates :ecosystem_uuid,  presence: true
  validates :student_uuid,    presence: true
  validates :assignment_type, presence: true
  validates :goal_num_tutor_assigned_spes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :goal_num_tutor_assigned_pes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
end

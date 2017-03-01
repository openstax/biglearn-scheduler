class Assignment < ApplicationRecord
  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  scope :with_instructor_based_sequence_numbers, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT *, row_number() OVER (
            PARTITION by student_uuid, assignment_type
            ORDER BY due_at ASC, opens_at ASC, created_at ASC
          ) AS instructor_based_sequence_number
          FROM assignments
        ) AS assignments
      SQL
    )
  end

  validates :course_uuid,     presence: true
  validates :ecosystem_uuid,  presence: true
  validates :student_uuid,    presence: true
  validates :assignment_type, presence: true
  validates :goal_num_tutor_assigned_spes,
            presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :goal_num_tutor_assigned_pes,
            presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

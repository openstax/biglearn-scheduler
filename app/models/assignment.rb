class Assignment < ApplicationRecord
  has_many :assigned_exercises, primary_key: :uuid,
                                foreign_key: :assignment_uuid,
                                dependent: :destroy,
                                inverse_of: :assignment
  has_many :assignment_pes,     primary_key: :uuid,
                                foreign_key: :assignment_uuid,
                                dependent: :destroy,
                                inverse_of: :assignment
  has_many :assignment_spes,    primary_key: :uuid,
                                foreign_key: :assignment_uuid,
                                dependent: :destroy,
                                inverse_of: :assignment
  has_one :exercise_calculation,
    -> { where '"exercise_calculations"."ecosystem_uuid" = "assignments"."ecosystem_uuid"' },
    primary_key: :student_uuid,
    foreign_key: :student_uuid,
    inverse_of: :assignments

  scope :need_spes, -> do
    where(
      arel_table[:spes_are_assigned].eq(false).and(
        arel_table[:goal_num_tutor_assigned_spes].eq(nil).or(
          arel_table[:goal_num_tutor_assigned_spes].gt(0)
        )
      )
    )
  end
  scope :need_pes, -> do
    where(
      arel_table[:pes_are_assigned].eq(false).and(
        arel_table[:goal_num_tutor_assigned_pes].eq(nil).or(
          arel_table[:goal_num_tutor_assigned_pes].gt(0)
        )
      )
    )
  end
  scope :need_spes_or_pes, -> do
    need_spes.or(need_pes)
  end

  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  scope :with_instructor_and_student_driven_sequence_numbers,
        ->(student_uuids: nil, assignment_types: nil) do
    wheres = []
    unless student_uuids.nil?
      wheres << if student_uuids.empty?
        'FALSE'
      else
        "assignments.student_uuid IN (#{
          student_uuids.map { |uuid| "'#{uuid}'" }.join(', ')
        })"
      end
    end
    unless assignment_types.nil?
      wheres << if assignment_types.empty?
        'FALSE'
      else
        "assignments.assignment_type IN (#{
          assignment_types.map { |type| "'#{type}'" }.join(', ')
        })"
      end
    end

    from(
      <<-SQL.strip_heredoc
        (
          SELECT assignments.*, assignment_core_steps_completion.core_steps_completed_at,
            row_number() OVER (
              PARTITION BY assignments.student_uuid, assignments.assignment_type
              ORDER BY assignments.due_at ASC, assignments.opens_at ASC, assignments.created_at ASC
            ) AS instructor_driven_sequence_number,
            row_number() OVER (
              PARTITION BY assignments.student_uuid, assignments.assignment_type
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
              GROUP BY assigned_exercises.assignment_uuid
              HAVING COUNT(assigned_exercises.*) = COUNT(DISTINCT responses.trial_uuid)
            ) AS assignment_core_steps_completion
              ON assignment_core_steps_completion.assignment_uuid = assignments.uuid
          #{"WHERE #{wheres.join(' AND ')}" unless wheres.empty?}
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

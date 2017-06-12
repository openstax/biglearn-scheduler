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
        ->(student_uuids: nil, assignment_types: nil, current_time: nil) do
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
    current_time ||= Time.current

    # We use DENSE_RANK() for the student history because we want all assignments
    # not yet in the student history to receive SPEs as if they were next in line
    # One of the conditions for adding an assignment to the student history is answering questions
    # and we do recalculate all outstanding SPEs for that student after every question answered
    # Unfortunately, we don't yet recalculate all SPEs for a student after an incomplete assignment
    # becomes due (the other condition for adding assignments to the student history)
    # Avoiding stale SPEs when incomplete assignments become due would probably require
    # a background job checking that condition periodically
    from(
      <<-SQL.strip_heredoc
        (
          SELECT assignments.*,
            assignment_core_step_responses.student_history_at,
            ROW_NUMBER() OVER (
              PARTITION BY assignments.student_uuid, assignments.assignment_type
              ORDER BY assignments.due_at ASC, assignments.opens_at ASC, assignments.created_at ASC
            ) AS instructor_driven_sequence_number,
            DENSE_RANK() OVER (
              PARTITION BY assignments.student_uuid, assignments.assignment_type
              ORDER BY assignment_core_step_responses.student_history_at ASC
            ) AS student_driven_sequence_number
          FROM assignments
            LEFT OUTER JOIN LATERAL (
              SELECT CASE
                WHEN EVERY(responses.id IS NOT NULL)
                  THEN MAX(responses.first_responded_at)
                WHEN assignments.due_at <= '#{current_time.to_s(:db)}'
                  THEN assignments.due_at
                END AS student_history_at
              FROM assigned_exercises
              LEFT OUTER JOIN responses
                ON responses.trial_uuid = assigned_exercises.uuid
                  AND (
                    assignments.due_at IS NULL
                      OR responses.first_responded_at <= assignments.due_at
                  )
              WHERE assigned_exercises.assignment_uuid = assignments.uuid
                AND assigned_exercises.is_spe = FALSE
              GROUP BY assigned_exercises.assignment_uuid
            ) AS assignment_core_step_responses
              ON TRUE
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

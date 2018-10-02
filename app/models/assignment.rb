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

  belongs_to :student, primary_key: :uuid,
                       foreign_key: :student_uuid,
                       optional: true,
                       inverse_of: :assignments

  unique_index :uuid

  scope :need_pes, -> do
    where(
      arel_table[:pes_are_assigned].eq(false).and(
        arel_table[:goal_num_tutor_assigned_pes].eq(nil).or(
          arel_table[:goal_num_tutor_assigned_pes].gt(0)
        )
      )
    )
  end
  scope :need_spes, -> do
    where(
      arel_table[:spes_are_assigned].eq(false).and(
        arel_table[:goal_num_tutor_assigned_spes].eq(nil).or(
          arel_table[:goal_num_tutor_assigned_spes].gt(0)
        )
      )
    )
  end
  scope :need_pes_or_spes, -> do
    need_pes.or(need_spes)
  end

  def needs_pes?
    !pes_are_assigned && (goal_num_tutor_assigned_pes.nil? || goal_num_tutor_assigned_pes > 0)
  end
  def needs_spes?
    !spes_are_assigned && (goal_num_tutor_assigned_spes.nil? || goal_num_tutor_assigned_spes > 0)
  end

  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  def self.with_instructor_and_student_driven_sequence_numbers_subquery(
    student_uuids: nil, assignment_types: nil
  )
    # We use DENSE_RANK() for the student history because we want all assignments
    # not yet in the student history to receive SPEs as if they were next in line
    # This is also why we return NULL for all the student_history tiebreakers
    # if student_history_at is NULL
    rel = select(
      <<-SELECT_SQL.strip_heredoc
        "assignments".*,
          ROW_NUMBER() OVER (
            PARTITION BY "assignments"."student_uuid", "assignments"."assignment_type"
            ORDER BY "assignments"."due_at" ASC,
              "assignments"."opens_at" ASC,
              "assignments"."created_at" ASC
          ) AS "instructor_driven_sequence_number",
          DENSE_RANK() OVER (
            PARTITION BY "assignments"."student_uuid", "assignments"."assignment_type"
            ORDER BY "assignments"."student_history_at" ASC,
              CASE
                WHEN "assignments"."student_history_at" IS NULL THEN NULL
                ELSE "assignments"."due_at"
              END ASC,
              CASE
                WHEN "assignments"."student_history_at" IS NULL THEN NULL
                ELSE "assignments"."opens_at"
              END ASC,
              CASE
                WHEN "assignments"."student_history_at" IS NULL THEN NULL
                ELSE "assignments"."created_at"
              END ASC
          ) AS "student_driven_sequence_number"
      SELECT_SQL
    )

    rel = rel.where(student_uuid: student_uuids) unless student_uuids.nil?
    rel = rel.where(assignment_type: assignment_types) unless assignment_types.nil?

    rel
  end

  def self.to_a_with_instructor_and_student_driven_sequence_numbers_cte(
    student_uuids: nil, assignment_types: nil
  )
    find_by_sql(
      <<-SQL.strip_heredoc
        WITH "assignments" AS (
          #{
            unscoped.with_instructor_and_student_driven_sequence_numbers_subquery(
              student_uuids: student_uuids,
              assignment_types: assignment_types
            ).to_sql
          }
        ) #{all.to_sql}
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

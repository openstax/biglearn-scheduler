class EcosystemExercise < ApplicationRecord
  belongs_to :ecosystem, primary_key: :uuid,
                         foreign_key: :ecosystem_uuid,
                         inverse_of: :ecosystem_exercises

  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        inverse_of: :ecosystem_exercises

  has_many :responses,
    -> { where '"ecosystem_exercises"."exercise_uuid" = "responses"."exercise_uuid"' },
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises
  def responses
    Response.where ecosystem_uuid: ecosystem_uuid, exercise_uuid: exercise_uuid
  end

  has_many :student_clue_calculations,
    -> do
      where(
        <<-WHERE_SQL.strip_heredoc
          "student_clue_calculations"."exercise_uuids" &&
          ARRAY["ecosystem_exercises"."exercise_uuid"]::varchar[]
        WHERE_SQL
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises
  def student_clue_calculations
    sanitized_exercise_uuid = self.class.sanitize exercise_uuid
    StudentClueCalculation.where(ecosystem_uuid: ecosystem_uuid).where(
      <<-WHERE_SQL.strip_heredoc
        "student_clue_calculations"."exercise_uuids" && ARRAY[#{sanitized_exercise_uuid}]::varchar[]
      WHERE_SQL
    )
  end

  has_many :teacher_clue_calculations,
    -> do
      where(
        <<-WHERE_SQL.strip_heredoc
          "teacher_clue_calculations"."exercise_uuids" &&
          ARRAY["ecosystem_exercises"."exercise_uuid"]::varchar[]
        WHERE_SQL
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises
  def teacher_clue_calculations
    sanitized_exercise_uuid = self.class.sanitize exercise_uuid
    TeacherClueCalculation.where(ecosystem_uuid: ecosystem_uuid).where(
      <<-WHERE_SQL.strip_heredoc
        "teacher_clue_calculations"."exercise_uuids" && ARRAY[#{sanitized_exercise_uuid}]::varchar[]
      WHERE_SQL
    )
  end

  unique_index :exercise_uuid, :ecosystem_uuid

  validates :book_container_uuids, presence: true

  scope :with_group_uuids, -> do
    joins(:exercise).select [arel_table[Arel.star], Exercise.arel_table[:group_uuid]]
  end
end

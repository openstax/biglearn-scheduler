class TeacherClueCalculation < ApplicationRecord
  include JsonSerialize

  json_serialize :responses, Hash, array: true

  has_many :algorithm_teacher_clue_calculations, primary_key: :uuid,
                                                 foreign_key: :teacher_clue_calculation_uuid,
                                                 dependent: :destroy,
                                                 inverse_of: :teacher_clue_calculation

  has_many :ecosystem_exercises,
    -> do
      where(
        <<-WHERE_SQL.strip_heredoc
          "teacher_clue_calculations"."exercise_uuids" &&
          ARRAY["ecosystem_exercises"."exercise_uuid"]
        WHERE_SQL
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :teacher_clue_calculations
  def ecosystem_exercises
    sanitized_exercise_uuids = exercise_uuids.map { |uuid| "#{self.class.sanitize uuid}" }
                                             .join(', ')
    EcosystemExercise.where(ecosystem_uuid: ecosystem_uuid).where(
      "\"ecosystem_exercises\".\"exercise_uuid\" IN (#{sanitized_exercise_uuids})"
    )
  end

  unique_index :course_container_uuid, :book_container_uuid

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuids,       presence: true
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true
end

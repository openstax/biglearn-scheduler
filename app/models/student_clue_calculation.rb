class StudentClueCalculation < ApplicationRecord
  include JsonSerialize

  json_serialize :responses, Hash, array: true

  has_many :algorithm_student_clue_calculations, primary_key: :uuid,
                                                 foreign_key: :student_clue_calculation_uuid,
                                                 dependent: :destroy,
                                                 inverse_of: :student_clue_calculation

  has_many :ecosystem_exercises,
    -> do
      where(
        <<~WHERE_SQL
          "student_clue_calculations"."exercise_uuids" &&
          ARRAY["ecosystem_exercises"."exercise_uuid"]
        WHERE_SQL
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :student_clue_calculations
  def ecosystem_exercises
    sanitized_exercise_uuids = exercise_uuids.map { |uuid| "#{self.class.sanitize uuid}" }
                                             .join(', ')
    EcosystemExercise.where(ecosystem_uuid: ecosystem_uuid).where(
      "\"ecosystem_exercises\".\"exercise_uuid\" IN (#{sanitized_exercise_uuids})"
    )
  end

  unique_index :student_uuid, :book_container_uuid

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuid,        presence: true, uniqueness: { scope: :book_container_uuid }
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true

  def student_uuids
    [ student_uuid ]
  end
end

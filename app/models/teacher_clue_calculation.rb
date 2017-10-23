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
        '"ecosystem_exercises"."exercise_uuid" = ANY("teacher_clue_calculations"."exercise_uuids")'
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :teacher_clue_calculations

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuids,       presence: true
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true
end

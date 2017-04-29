class TeacherClueCalculation < ApplicationRecord
  include JsonSerialize

  json_serialize :responses, Hash, array: true

  has_many :algorithm_teacher_clue_calculations, primary_key: :uuid,
                                                 foreign_key: :teacher_clue_calculation_uuid,
                                                 inverse_of: :teacher_clue_calculation

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuids,       presence: true
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true
end

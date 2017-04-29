class StudentClueCalculation < ApplicationRecord
  include JsonSerialize

  json_serialize :responses, Hash, array: true

  has_many :algorithm_student_clue_calculations, primary_key: :uuid,
                                                 foreign_key: :student_clue_calculation_uuid,
                                                 inverse_of: :student_clue_calculation

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuid,        presence: true, uniqueness: { scope: :book_container_uuid }
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true

  def student_uuids
    [ student_uuid ]
  end
end

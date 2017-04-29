class StudentPeCalculation < ApplicationRecord
  has_many :student_pe_calculation_exercises, primary_key: :uuid,
                                              foreign_key: :student_pe_calculation_uuid,
                                              dependent: :destroy,
                                              inverse_of: :student_pe_calculation
  has_many :algorithm_student_pe_calculations, primary_key: :uuid,
                                               foreign_key: :student_pe_calculation_uuid,
                                               dependent: :destroy,
                                               inverse_of: :student_pe_calculation

  validates :clue_algorithm_name, presence: true
  validates :ecosystem_uuid,      presence: true
  validates :student_uuid,        presence: true
  validates :book_container_uuid, presence: true, uniqueness: { scope: :student_uuid }
  validates :exercise_uuids,      presence: true
  validates :exercise_count,      presence: true,
                                  numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

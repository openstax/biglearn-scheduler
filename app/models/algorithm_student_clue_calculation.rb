class AlgorithmStudentClueCalculation < ApplicationRecord
  validates :student_clue_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :student_clue_calculation_uuid }
  validates :clue_data, presence: true
  validates :student_uuid, presence: true
  validates :clue_value, presence: true
end

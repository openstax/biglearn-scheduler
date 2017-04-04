class AlgorithmTeacherClueCalculation < ApplicationRecord
  validates :teacher_clue_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :teacher_clue_calculation_uuid }
  validates :clue_value, presence: true
end

class AlgorithmStudentPeCalculation < ApplicationRecord
  validates :student_pe_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :student_pe_calculation_uuid }
end

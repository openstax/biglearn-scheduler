class AlgorithmAssignmentPeCalculation < ApplicationRecord
  validates :assignment_pe_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :assignment_pe_calculation_uuid }
end

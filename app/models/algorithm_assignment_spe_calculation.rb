class AlgorithmAssignmentSpeCalculation < ApplicationRecord
  validates :assignment_spe_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :assignment_spe_calculation_uuid }
end

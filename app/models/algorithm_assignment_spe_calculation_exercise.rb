class AlgorithmAssignmentSpeCalculationExercise < ApplicationRecord
  validates :algorithm_assignment_spe_calculation_uuid, presence: true
  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :algorithm_assignment_spe_calculation_uuid }
end

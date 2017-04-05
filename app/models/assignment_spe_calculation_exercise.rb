class AssignmentSpeCalculationExercise < ApplicationRecord
  validates :assignment_spe_calculation_uuid, presence: true
  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :assignment_spe_calculation_uuid }
end

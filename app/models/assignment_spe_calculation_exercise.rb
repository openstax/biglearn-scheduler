# Used to detect AssignmentSpeCalculations that must be updated
class AssignmentSpeCalculationExercise < ApplicationRecord
  belongs_to :assignment_spe_calculation, primary_key: :uuid,
                                          foreign_key: :assignment_spe_calculation_uuid,
                                          inverse_of: :assignment_spe_calculation_exercises

  validates :assignment_spe_calculation, presence: true
  validates :exercise_uuid, presence: true, uniqueness: { scope: :assignment_spe_calculation_uuid }
end

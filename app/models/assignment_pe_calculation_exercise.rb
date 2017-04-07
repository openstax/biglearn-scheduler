# Used to detect AssignmentPeCalculations that must be updated
class AssignmentPeCalculationExercise < ApplicationRecord
  validates :assignment_pe_calculation_uuid, presence: true
  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :assignment_pe_calculation_uuid }
end

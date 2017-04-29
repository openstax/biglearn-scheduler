# Used to detect AssignmentPeCalculations that must be updated
class AssignmentPeCalculationExercise < ApplicationRecord
  belongs_to :assignment_pe_calculation, primary_key: :uuid,
                                         foreign_key: :assignment_pe_calculation_uuid,
                                         inverse_of: :assignment_pe_calculation_exercises

  validates :assignment_pe_calculation, presence: true
  validates :exercise_uuid, presence: true, uniqueness: { scope: :assignment_pe_calculation_uuid }
end

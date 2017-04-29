# Used to detect StudentPeCalculations that must be updated
class StudentPeCalculationExercise < ApplicationRecord
  belongs_to :student_pe_calculation, primary_key: :uuid,
                                      foreign_key: :student_pe_calculation_uuid,
                                      inverse_of: :student_pe_calculation_exercises

  validates :student_pe_calculation, presence: true
  validates :exercise_uuid, presence: true, uniqueness: { scope: :student_pe_calculation_uuid }
end

class StudentPeCalculationExercise < ApplicationRecord
  validates :student_pe_calculation_uuid, presence: true
  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :student_pe_calculation_uuid }
end

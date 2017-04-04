class AlgorithmStudentPeCalculationExercise < ApplicationRecord
  validates :algorithm_student_pe_calculation_uuid, presence: true
  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :algorithm_student_pe_calculation_uuid }
end

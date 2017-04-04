class AlgorithmExerciseCalculation < ApplicationRecord
  validates :exercise_calculation_uuid, presence: true
  validates :algorithm_name,            presence: true,
                                        uniqueness: { scope: :exercise_calculation_uuid }
end

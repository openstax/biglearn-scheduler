# Used to detect StudentPes that must be updated
class StudentPe < ApplicationRecord
  CLUE_TO_EXERCISE_ALGORITHM_NAME = { 'local_query' => 'local_query', 'sparfa' => 'tesr' }
  EXERCISE_TO_CLUE_ALGORITHM_NAME = { 'local_query' => 'local_query', 'tesr' => 'sparfa' }

  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :student_pes

  unique_index :algorithm_exercise_calculation_uuid, :exercise_uuid

  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :algorithm_exercise_calculation_uuid }

  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "student_pes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

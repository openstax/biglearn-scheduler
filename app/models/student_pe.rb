# Used to detect StudentPes that must be updated
class StudentPe < ApplicationRecord
  CLUE_TO_EXERCISE_ALGORITHM_NAME = { 'local_query' => 'local_query', 'sparfa' => 'tesr' }
  EXERCISE_TO_CLUE_ALGORITHM_NAME = { 'local_query' => 'local_query', 'tesr' => 'sparfa' }

  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :student_pes

  validates :exercise_uuid, uniqueness: { scope: :algorithm_exercise_calculation_uuid }

  scope :with_student_uuids, -> do
    joins(algorithm_exercise_calculation: :exercise_calculation).select [
      arel_table[Arel.star], ExerciseCalculation.arel_table[:student_uuid]
    ]
  end
  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "student_pes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

# Used to detect AssignmentPes that must be updated
class AssignmentPe < ApplicationRecord
  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :assignment_pes
  belongs_to :assignment,                     primary_key: :uuid,
                                              foreign_key: :assignment_uuid,
                                              inverse_of: :assignment_pes

  validates :assignment_uuid, presence: true
  validates :exercise_uuid, presence: true, uniqueness: {
    scope: [ :assignment_uuid, :algorithm_exercise_calculation_uuid ]
  }

  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "assignment_pes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

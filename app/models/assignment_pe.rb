# Used to detect AssignmentPes that must be updated
class AssignmentPe < ApplicationRecord
  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :assignment_pes
  belongs_to :assignment,                     primary_key: :uuid,
                                              foreign_key: :assignment_uuid,
                                              inverse_of: :assignment_pes

  has_many :conflicting_assignment_spes,
           -> { where '"assignment_spes"."exercise_uuid" = "assignment_pes"."exercise_uuid"' },
           class_name: 'AssignmentSpe',
           primary_key: :assignment_uuid,
           foreign_key: :assignment_uuid,
           inverse_of: :conflicting_assignment_pes
  def conflicting_assignment_spes
    AssignmentSpe.where assignment_uuid: assignment_uuid, exercise_uuid: exercise_uuid
  end

  unique_index :assignment_uuid, :algorithm_exercise_calculation_uuid, :exercise_uuid

  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "assignment_pes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

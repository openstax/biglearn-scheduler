# Used to detect AssignmentSpes that must be updated
class AssignmentSpe < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :assignment_spes
  belongs_to :assignment,                     primary_key: :uuid,
                                              foreign_key: :assignment_uuid,
                                              inverse_of: :assignment_spes

  has_many :conflicting_assignment_pes,
           -> { where '"assignment_pes"."exercise_uuid" = "assignment_spes"."exercise_uuid"' },
           class_name: 'AssignmentPe',
           primary_key: :assignment_uuid,
           foreign_key: :assignment_uuid,
           inverse_of: :conflicting_assignment_spes

  validates :assignment_uuid, presence: true
  validates :exercise_uuid, presence: true, uniqueness: {
    scope: [ :assignment_uuid, :algorithm_exercise_calculation_uuid, :history_type ]
  }
  validates :history_type, presence: true

  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "assignment_spes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

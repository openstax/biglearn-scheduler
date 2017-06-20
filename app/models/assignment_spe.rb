# Used to detect AssignmentSpes that must be updated
class AssignmentSpe < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :assignment_spes
  belongs_to :assignment,                     primary_key: :uuid,
                                              foreign_key: :assignment_uuid,
                                              inverse_of: :assignment_spes

  validates :assignment_uuid, presence: true
  validates :exercise_uuid, presence: true, uniqueness: {
    scope: [ :assignment_uuid, :algorithm_exercise_calculation_uuid, :history_type ]
  }
  validates :history_type, presence: true

  scope :with_student_uuids, -> do
    joins(:assignment).select [ arel_table[Arel.star], Assignment.arel_table[:student_uuid] ]
  end
  scope :unassociated, -> do
    where.not(
      AlgorithmExerciseCalculation.where(
        '"uuid" = "assignment_spes"."algorithm_exercise_calculation_uuid"'
      ).exists
    )
  end
end

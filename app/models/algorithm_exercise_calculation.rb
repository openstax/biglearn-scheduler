class AlgorithmExerciseCalculation < ApplicationRecord
  has_many :assignment_spes, primary_key: :uuid,
                             foreign_key: :algorithm_exercise_calculation_uuid,
                             dependent: :destroy,
                             inverse_of: :algorithm_exercise_calculation
  has_many :assignment_pes,  primary_key: :uuid,
                             foreign_key: :algorithm_exercise_calculation_uuid,
                             dependent: :destroy,
                             inverse_of: :algorithm_exercise_calculation
  has_many :student_pes,     primary_key: :uuid,
                             foreign_key: :algorithm_exercise_calculation_uuid,
                             dependent: :destroy,
                             inverse_of: :algorithm_exercise_calculation

  belongs_to :exercise_calculation, primary_key: :uuid,
                                    foreign_key: :exercise_calculation_uuid,
                                    inverse_of: :algorithm_exercise_calculations

  validates :algorithm_name,       presence: true, uniqueness: { scope: :exercise_calculation_uuid }
  validates :exercise_uuids,       presence: true

  scope :unassociated, -> do
    where.not(
      ExerciseCalculation.where(
        '"uuid" = "algorithm_exercise_calculations"."exercise_calculation_uuid"'
      ).exists
    )
  end
end

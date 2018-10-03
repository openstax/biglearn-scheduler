class ExerciseCalculation < ApplicationRecord
  has_many :algorithm_exercise_calculations, primary_key: :uuid,
                                             foreign_key: :exercise_calculation_uuid,
                                             dependent: :destroy,
                                             inverse_of: :exercise_calculation

  has_many :assignments,
    -> { where '"assignments"."ecosystem_uuid" = "exercise_calculations"."ecosystem_uuid"' },
    primary_key: :student_uuid,
    foreign_key: :student_uuid,
    inverse_of: :exercise_calculation
  def assignments
    Assignment.where student_uuid: student_uuid, ecosystem_uuid: ecosystem_uuid
  end

  belongs_to :ecosystem, primary_key: :uuid,
                         foreign_key: :ecosystem_uuid,
                         inverse_of: :exercise_calculations

  belongs_to :student, primary_key: :uuid,
                       foreign_key: :student_uuid,
                       inverse_of: :exercise_calculations

  unique_index :student_uuid, :ecosystem_uuid

  scope :with_exercise_uuids, -> do
    joins(:ecosystem).select('"exercise_calculations".*, "ecosystems"."exercise_uuids"')
  end
end

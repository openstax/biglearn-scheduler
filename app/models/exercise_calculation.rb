class ExerciseCalculation < ApplicationRecord
  DEFAULT_STUDENT_UUID = '00000000-0000-0000-0000-000000000000'

  has_many :algorithm_exercise_calculations, primary_key: :uuid,
                                             foreign_key: :exercise_calculation_uuid,
                                             dependent: :destroy,
                                             inverse_of: :exercise_calculation

  has_many :assignments,
    -> do
      where(
        Assignment.arel_table[:ecosystem_uuid].eq(ExerciseCalculation.arel_table[:ecosystem_uuid])
      )
    end,
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

  unique_index :uuid

  scope :with_exercise_uuids, -> do
    joins(:ecosystem).select('"exercise_calculations".*, "ecosystems"."exercise_uuids"')
  end

  scope :superseded,     -> { where.not superseded_at: nil }
  scope :not_superseded, -> { where     superseded_at: nil }

  scope :default, -> { where student_uuid: DEFAULT_STUDENT_UUID }
end

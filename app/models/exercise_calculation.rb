class ExerciseCalculation < ApplicationRecord
  has_many :algorithm_exercise_calculations, primary_key: :uuid,
                                             foreign_key: :exercise_calculation_uuid,
                                             dependent: :destroy,
                                             inverse_of: :exercise_calculation

  ec = arel_table
  has_many :assignments,
    -> { where arel_table[:ecosystem_uuid].eq(ec[:ecosystem_uuid]) },
    primary_key: :student_uuid,
    foreign_key: :student_uuid,
    inverse_of: :exercise_calculation
  def assignments
    Assignment.where student_uuid: student_uuid, ecosystem_uuid: ecosystem_uuid
  end

  has_many :supersededs, class_name: name,
                         primary_key: :uuid,
                         foreign_key: :superseded_by_uuid,
                         inverse_of: :superseded_by

  belongs_to :superseded_by, class_name: name,
                             primary_key: :uuid,
                             foreign_key: :superseded_by_uuid,
                             optional: true,
                             inverse_of: :supersededs

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

  scope :superseded,     -> { where.not superseded_by_uuid: nil }
  scope :not_superseded, -> { where     superseded_by_uuid: nil }
end

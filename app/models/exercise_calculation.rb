class ExerciseCalculation < ApplicationRecord
  validates :ecosystem_uuid, presence: true
  validates :student_uuid,   presence: true
  validates :exercise_uuids, presence: true
end

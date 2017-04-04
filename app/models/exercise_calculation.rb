class ExerciseCalculation < ApplicationRecord
  validates :algorithm_name, presence: true
  validates :exercise_uuids, presence: true
  validates :student_uuids,  presence: true
  validates :ecosystem_uuid, presence: true
end

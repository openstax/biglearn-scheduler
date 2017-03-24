class AssignedExercise < ApplicationRecord
  validates :assignment_uuid, presence: true
  validates :exercise_uuid,   presence: true
end

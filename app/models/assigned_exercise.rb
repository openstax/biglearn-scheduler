class AssignedExercise < ApplicationRecord
  validates :assignment_uuid, presence: true
end

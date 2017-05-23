class AssignedExercise < ApplicationRecord
  belongs_to :assignment, primary_key: :uuid,
                          foreign_key: :assignment_uuid,
                          inverse_of: :assigned_exercises

  validates :exercise_uuid,   presence: true
end

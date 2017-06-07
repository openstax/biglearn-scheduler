class AssignedExercise < ApplicationRecord
  belongs_to :assignment, primary_key: :uuid,
                          foreign_key: :assignment_uuid,
                          inverse_of: :assigned_exercises

  has_many :responses, primary_key: :uuid,
                       foreign_key: :trial_uuid,
                       inverse_of: :responses

  validates :exercise_uuid,   presence: true
end

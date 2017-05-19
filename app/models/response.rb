class Response < ApplicationRecord
  validates :ecosystem_uuid, presence: true
  validates :trial_uuid,     presence: true
  validates :student_uuid,   presence: true
  validates :exercise_uuid,  presence: true
  validates :responded_at,   presence: true
end

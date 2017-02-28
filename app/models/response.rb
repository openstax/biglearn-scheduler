class Response < ApplicationRecord
  has_one :response_clue, primary_key: :uuid, foreign_key: :uuid

  validates :student_uuid,  presence: true
  validates :exercise_uuid, presence: true
  validates :responded_at,  presence: true
end

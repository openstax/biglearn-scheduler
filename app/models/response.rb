class Response < ApplicationRecord
  belongs_to :student, primary_key: :uuid, foreign_key: :student_uuid
  belongs_to :exercise, primary_key: :uuid, foreign_key: :exercise_uuid

  has_one :course, through: :student
  has_one :response_clue, primary_key: :uuid, foreign_key: :uuid

  validates :student_uuid,  presence: true
  validates :exercise_uuid, presence: true
  validates :responded_at,  presence: true
end

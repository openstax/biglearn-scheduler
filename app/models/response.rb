class Response < ApplicationRecord
  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        optional: true,
                        inverse_of: :responses

  validates :ecosystem_uuid, presence: true
  validates :trial_uuid,     presence: true
  validates :student_uuid,   presence: true
  validates :exercise_uuid,  presence: true
  validates :responded_at,   presence: true
end

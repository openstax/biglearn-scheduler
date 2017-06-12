class Response < ApplicationRecord
  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        optional: true,
                        inverse_of: :responses

  belongs_to :assigned_exercise, primary_key: :uuid,
                                 foreign_key: :trial_uuid,
                                 optional: true,
                                 inverse_of: :responses

  validates :ecosystem_uuid, presence: true
  validates :trial_uuid,     presence: true
  validates :student_uuid,   presence: true
  validates :exercise_uuid,  presence: true
  validates :first_responded_at,   presence: true
  validates :last_responded_at,   presence: true
end

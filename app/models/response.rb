class Response < ApplicationRecord
  belongs_to :student, primary_key: :uuid,
                       foreign_key: :student_uuid,
                       optional: true,
                       inverse_of: :responses

  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        optional: true,
                        inverse_of: :responses

  belongs_to :assigned_exercise, primary_key: :uuid,
                                 foreign_key: :trial_uuid,
                                 optional: true,
                                 inverse_of: :responses

  has_many :ecosystem_exercises,
    -> { where '"ecosystem_exercises"."exercise_uuid" = "responses"."exercise_uuid"' },
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :responses

  unique_index :uuid

  validates :ecosystem_uuid,     presence: true
  validates :trial_uuid,         presence: true
  validates :student_uuid,       presence: true
  validates :exercise_uuid,      presence: true
  validates :first_responded_at, presence: true
  validates :last_responded_at,  presence: true
end

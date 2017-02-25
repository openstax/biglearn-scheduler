class Response < ActiveRecord::Base
  include HasUniqueUuid

  belongs_to :student, primary_key: :uuid, foreign_key: :student_uuid

  validates :student_uuid,  presence: true
  validates :exercise_uuid, presence: true
  validates :responded_at,  presence: true
end

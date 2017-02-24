class Response < ActiveRecord::Base
  include HasUniqueUuid

  validates :student_uuid,  presence: true
  validates :exercise_uuid, presence: true
  validates :responded_at,  presence: true
end

class ResponseClue < ApplicationRecord
  validates :course_uuid, presence: true
end

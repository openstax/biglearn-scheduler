class CourseContainer < ApplicationRecord
  validates :course_uuid, presence: true
end

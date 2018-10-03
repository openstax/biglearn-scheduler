class CourseContainer < ApplicationRecord
  unique_index :uuid

  validates :course_uuid, presence: true
end

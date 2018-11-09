class CourseContainer < ApplicationRecord
  belongs_to :course, primary_key: :uuid,
                      foreign_key: :course_uuid,
                      inverse_of: :course_containers

  unique_index :uuid, scoped_to: :course

  validates :course_uuid, presence: true
end

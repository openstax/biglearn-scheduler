class CourseContainer < ActiveRecord::Base
  include HasUniqueUuid

  validates :course_uuid, presence: true
end

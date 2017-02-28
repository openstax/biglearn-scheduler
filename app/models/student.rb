class Student < ApplicationRecord
  validates :course_uuid,            presence: true
  validates :course_container_uuids, presence: true
end

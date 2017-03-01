class Student < ApplicationRecord
  belongs_to :course, primary_key: :uuid, foreign_key: :course_uuid

  validates :course_uuid,            presence: true
  validates :course_container_uuids, presence: true
end

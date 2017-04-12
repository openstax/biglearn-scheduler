class TeacherClueCalculation < ApplicationRecord
  include JsonSerialize

  json_serialize :responses, Hash, array: true

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuids,       presence: true
  validates :exercise_uuids,      presence: true
  validates :responses,           presence: true
end

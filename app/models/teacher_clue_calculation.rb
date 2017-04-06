class TeacherClueCalculation < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuids,       presence: true
  validates :exercise_uuids,      presence: true
  validates :response_uuids,      presence: true
end

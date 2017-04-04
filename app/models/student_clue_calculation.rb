class StudentClueCalculation < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuid,        presence: true, uniqueness: { scope: :book_container_uuid }
  validates :exercise_uuids,      presence: true
end

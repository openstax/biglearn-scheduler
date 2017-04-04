class StudentPeCalculation < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :student_uuid,        presence: true
  validates :book_container_uuid, presence: true, uniqueness: { scope: :student_uuid }
  validates :exercise_uuids,      presence: true
end

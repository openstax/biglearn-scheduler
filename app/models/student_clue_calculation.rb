class StudentClueCalculation < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuid,        presence: true, uniqueness: { scope: :book_container_uuid }
  validates :exercise_uuids,      presence: true
  validates :response_uuids,      presence: true

  def student_uuids
    [ student_uuid ]
  end
end

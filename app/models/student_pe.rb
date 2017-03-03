class StudentPe < ApplicationRecord
  validates :book_container_uuid, presence: true
  validates :student_uuid,        presence: true
  validates :exercise_uuid,       presence: true,
                                  uniqueness: { scope: :student_uuid }
end

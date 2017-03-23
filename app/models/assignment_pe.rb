class AssignmentPe < ApplicationRecord
  validates :student_uuid,        presence: true
  validates :assignment_uuid,     presence: true
  validates :book_container_uuid, presence: true
  validates :exercise_uuid,       presence: true,
                                  uniqueness: { scope: :assignment_uuid }
end

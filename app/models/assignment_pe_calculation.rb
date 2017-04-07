class AssignmentPeCalculation < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :assignment_uuid,     presence: true
  validates :book_container_uuid, presence: true, uniqueness: { scope: :assignment_uuid }
  validates :student_uuid,        presence: true
  validates :exercise_uuids,      presence: true
  validates :exercise_count,      presence: true,
                                  numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

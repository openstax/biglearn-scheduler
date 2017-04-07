class StudentPeCalculation < ApplicationRecord
  validates :clue_algorithm_name, presence: true
  validates :ecosystem_uuid,      presence: true
  validates :student_uuid,        presence: true
  validates :book_container_uuid, presence: true, uniqueness: { scope: :student_uuid }
  validates :exercise_uuids,      presence: true
  validates :exercise_count,      presence: true,
                                  numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

class StudentClue < ApplicationRecord
  validates :student_uuid,        presence: true
  validates :book_container_uuid, presence: true, uniqueness: { scope: :student_uuid }
  validates :value,               presence: true, numericality: {
    greater_than_or_equal_to: 0, less_than_or_equal_to: 1
  }
end

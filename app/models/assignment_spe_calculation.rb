class AssignmentSpeCalculation < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  validates :ecosystem_uuid, presence: true
  validates :assignment_uuid, presence: true
  validates :history_type, presence: true
  validates :k_ago, presence: true,
                    uniqueness: { scope: [:assignment_uuid, :book_container_uuid, :history_type] },
                    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :student_uuid, presence: true
  validates :exercise_uuids, presence: true
  validates :exercise_count, presence: true,
                             numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

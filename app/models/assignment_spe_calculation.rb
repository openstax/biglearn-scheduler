class AssignmentSpeCalculation < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  validates :ecosystem_uuid,      presence: true
  validates :assignment_uuid, presence: true
  validates :history_type,    presence: true
  validates :k_ago,           uniqueness: {
    scope: [:assignment_uuid, :book_container_uuid, :history_type]
  }
  validates :student_uuid,    presence: true
  validates :exercise_uuids,  presence: true
end

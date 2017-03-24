class AssignmentSpe < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  validates :student_uuid,    presence: true
  validates :assignment_uuid, presence: true
  validates :history_type,    presence: true
  validates :exercise_uuid,   presence: true,
                              uniqueness: { scope: [ :assignment_uuid, :history_type ] }
end

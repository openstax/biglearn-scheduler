class Assignment < ActiveRecord::Base
  include HasUniqueUuid

  validates :course_uuid,     presence: true
  validates :ecosystem_uuid,  presence: true
  validates :student_uuid,    presence: true
  validates :assignment_type, presence: true
  validates :goal_num_tutor_assigned_spes,
            presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :goal_num_tutor_assigned_pes,
            presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

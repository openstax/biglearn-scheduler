class AssignmentPe < ActiveRecord::Base
  include HasUniqueUuid

  validates :assignment_uuid, presence: true
  validates :exercise_uuid,   presence: true,
                              uniqueness: { scope: :assignment_uuid }
end

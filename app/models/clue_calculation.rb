class ClueCalculation < ApplicationRecord
  validates :ecosystem_uuid, presence: true
  validates :exercise_uuids, presence: true
  validates :student_uuids,  presence: true
end

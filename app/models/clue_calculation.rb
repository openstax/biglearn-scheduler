class ClueCalculation < ApplicationRecord
  validates :algorithm_uuid, presence: true
  validates :exercise_uuids, presence: true
  validates :student_uuids,  presence: true
end

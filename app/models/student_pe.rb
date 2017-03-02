class StudentPe < ApplicationRecord
  validates :student_uuid,         presence: true
  validates :exercise_uuid,        presence: true,
                                   uniqueness: { scope: :student_uuid }
end

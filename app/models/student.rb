class Student < ApplicationRecord
  NUM_WORST_CLUES = 5

  has_many :worst_student_clues,
           -> { order(:value).limit(NUM_WORST_CLUES) },
           class_name: 'StudentClue',
           primary_key: :uuid,
           foreign_key: :student_uuid

  validates :course_uuid,            presence: true
  validates :course_container_uuids, presence: true
end

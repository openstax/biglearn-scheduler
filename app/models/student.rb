class Student < ApplicationRecord
  has_many :assignments, primary_key: :uuid,
                         foreign_key: :student_uuid,
                         inverse_of: :student

  has_many :responses, primary_key: :uuid,
                       foreign_key: :student_uuid,
                       inverse_of: :student

  has_many :exercise_calculations, primary_key: :uuid,
                                   foreign_key: :student_uuid,
                                   dependent: :destroy,
                                   inverse_of: :student

  has_many :student_clue_calculations, primary_key: :uuid,
                                       foreign_key: :student_uuid,
                                       dependent: :destroy,
                                       inverse_of: :student

  belongs_to :course, primary_key: :uuid,
                      foreign_key: :course_uuid,
                      inverse_of: :students

  unique_index :uuid

  validates :course_container_uuids, presence: true
end

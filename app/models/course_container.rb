class CourseContainer < ApplicationRecord
  has_many :teacher_clue_calculations, primary_key: :uuid,
                                       foreign_key: :course_container_uuid,
                                       dependent: :destroy,
                                       inverse_of: :course_container

  belongs_to :course, primary_key: :uuid,
                      foreign_key: :course_uuid,
                      inverse_of: :course_containers

  unique_index :uuid
end

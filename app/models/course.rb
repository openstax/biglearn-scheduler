class Course < ApplicationRecord
  has_many :course_containers, primary_key: :uuid,
                               foreign_key: :course_uuid,
                               dependent: :destroy,
                               inverse_of: :course

  has_many :students, primary_key: :uuid,
                      foreign_key: :course_uuid,
                      dependent: :destroy,
                      inverse_of: :course

  unique_index :uuid

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ecosystem_uuid,  presence: true
end

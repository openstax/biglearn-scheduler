class ExercisePool < ApplicationRecord
  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
end

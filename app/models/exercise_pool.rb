class ExercisePool < ApplicationRecord
  unique_index :uuid

  validates :ecosystem_uuid,      presence: true
  validates :book_container_uuid, presence: true
end

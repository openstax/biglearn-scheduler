class EcosystemExercise < ApplicationRecord
  validates :ecosystem_uuid,       presence: true
  validates :exercise_uuid,        presence: true
  validates :exercise_group_uuid,  presence: true
  validates :book_container_uuids, presence: true
end

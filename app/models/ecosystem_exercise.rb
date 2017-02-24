class EcosystemExercise < ActiveRecord::Base
  include HasUniqueUuid

  validates :ecosystem_uuid,       presence: true
  validates :exercise_group_uuid,  presence: true
  validates :book_container_uuids, presence: true
end

class EcosystemExercise < ActiveRecord::Base
  include HasUniqueUuid

  validates :exercise_uuid,        presence: true
  validates :ecosystem_uuid,       presence: true
  validates :book_container_uuids, presence: true
end

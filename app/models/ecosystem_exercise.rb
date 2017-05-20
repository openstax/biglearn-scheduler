class EcosystemExercise < ApplicationRecord
  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        inverse_of: :ecosystem_exercises

  validates :ecosystem_uuid,       presence: true
  validates :exercise,             presence: true
  validates :exercise_group_uuid,  presence: true
  validates :book_container_uuids, presence: true
end

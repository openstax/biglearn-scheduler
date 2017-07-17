class EcosystemExercise < ApplicationRecord
  belongs_to :ecosystem, primary_key: :uuid,
                         foreign_key: :ecosystem_uuid,
                         inverse_of: :ecosystem_exercises

  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        inverse_of: :ecosystem_exercises

  validates :book_container_uuids, presence: true

  scope :with_group_uuids, -> do
    joins(:exercise).select [arel_table[Arel.star], Exercise.arel_table[:group_uuid]]
  end
end

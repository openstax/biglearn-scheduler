class EcosystemExercise < ApplicationRecord
  belongs_to :ecosystem, primary_key: :uuid,
                         foreign_key: :ecosystem_uuid,
                         inverse_of: :ecosystem_exercises

  belongs_to :exercise, primary_key: :uuid,
                        foreign_key: :exercise_uuid,
                        inverse_of: :ecosystem_exercises

  has_many :responses,
    -> { where '"ecosystem_exercises"."exercise_uuid" = "responses"."exercise_uuid"' },
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises

  has_many :student_clue_calculations,
    -> do
      where(
        '"ecosystem_exercises"."exercise_uuid" = ANY("student_clue_calculations"."exercise_uuids")'
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises

  has_many :teacher_clue_calculations,
    -> do
      where(
        '"ecosystem_exercises"."exercise_uuid" = ANY("teacher_clue_calculations"."exercise_uuids")'
      )
    end,
    primary_key: :ecosystem_uuid,
    foreign_key: :ecosystem_uuid,
    inverse_of: :ecosystem_exercises

  validates :book_container_uuids, presence: true

  validates :next_ecosystem_matrix_update_response_count, presence: true,
                                                          numericality: { only_integer: true }

  scope :with_group_uuids, -> do
    joins(:exercise).select [arel_table[Arel.star], Exercise.arel_table[:group_uuid]]
  end
end

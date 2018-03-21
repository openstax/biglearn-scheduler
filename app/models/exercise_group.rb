class ExerciseGroup < ApplicationRecord
  has_many :exercises, primary_key: :uuid,
                       foreign_key: :group_uuid,
                       dependent: :destroy,
                       inverse_of: :exercise_group

  validates :response_count, :next_update_response_count,
            presence: true, numericality: { only_integer: true }
end

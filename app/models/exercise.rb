class Exercise < ApplicationRecord
  has_many :ecosystem_exercises, primary_key: :uuid,
                                 foreign_key: :exercise_uuid,
                                 inverse_of: :exercise,
                                 dependent: :destroy

  has_many :responses, primary_key: :uuid,
                       foreign_key: :exercise_uuid,
                       inverse_of: :exercise

  belongs_to :exercise_group, primary_key: :uuid,
                              foreign_key: :group_uuid,
                              inverse_of: :exercises

  validates :group_uuid, presence: true
  validates :version,    presence: true
end

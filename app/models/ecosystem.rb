class Ecosystem < ApplicationRecord
  has_many :ecosystem_exercises, primary_key: :uuid,
                                 foreign_key: :ecosystem_uuid,
                                 inverse_of: :ecosystem,
                                 dependent: :destroy

  has_many :exercise_calculations, primary_key: :uuid,
                                   foreign_key: :ecosystem_uuid,
                                   dependent: :destroy,
                                   inverse_of: :ecosystem

  unique_index :uuid

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

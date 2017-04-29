class AssignmentSpeCalculation < ApplicationRecord
  enum history_type: [ :instructor_driven, :student_driven ]

  has_many :assignment_spe_calculation_exercises, primary_key: :uuid,
                                                  foreign_key: :assignment_spe_calculation_uuid,
                                                  dependent: :destroy,
                                                  inverse_of: :assignment_spe_calculation
  has_many :algorithm_assignment_spe_calculations, primary_key: :uuid,
                                                   foreign_key: :assignment_spe_calculation_uuid,
                                                   dependent: :destroy,
                                                   inverse_of: :assignment_spe_calculation

  validates :ecosystem_uuid, presence: true
  validates :assignment_uuid, presence: true
  validates :history_type, presence: true
  validates :k_ago, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :is_spaced, uniqueness: {
                          scope: [:assignment_uuid, :book_container_uuid, :history_type, :k_ago]
                        }
  validates :student_uuid, presence: true
  validates :exercise_uuids, presence: true
  validates :exercise_count, presence: true,
                             numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

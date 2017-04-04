class AlgorithmClueCalculation < ApplicationRecord
  validates :clue_calculation_uuid, presence: true
  validates :algorithm_name,        presence: true, uniqueness: { scope: :clue_calculation_uuid }
end

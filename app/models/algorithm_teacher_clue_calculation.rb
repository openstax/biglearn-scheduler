class AlgorithmTeacherClueCalculation < ApplicationRecord
  belongs_to :teacher_clue_calculation, primary_key: :uuid,
                                        foreign_key: :teacher_clue_calculation_uuid,
                                        inverse_of: :algorithm_teacher_clue_calculations

  validates :teacher_clue_calculation, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :teacher_clue_calculation_uuid }
  validates :clue_data, presence: true
end

class AlgorithmTeacherClueCalculation < ApplicationRecord
  belongs_to :teacher_clue_calculation, primary_key: :uuid,
                                        foreign_key: :teacher_clue_calculation_uuid,
                                        inverse_of: :algorithm_teacher_clue_calculations

  unique_index :teacher_clue_calculation_uuid, :algorithm_name

  validates :clue_data, presence: true
end

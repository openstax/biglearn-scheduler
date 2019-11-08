# Used to detect StudentPes that must be updated
class StudentPe < ApplicationRecord
  belongs_to :algorithm_exercise_calculation, primary_key: :uuid,
                                              foreign_key: :algorithm_exercise_calculation_uuid,
                                              inverse_of: :student_pes

  unique_index :algorithm_exercise_calculation_uuid, :exercise_uuid

  validates :exercise_uuid, presence: true,
                            uniqueness: { scope: :algorithm_exercise_calculation_uuid }

  # In case we have to map algorithm names in the future
  def self.clue_to_exercise_algorithm_name(algorithm_name)
    algorithm_name
  end

  def self.exercise_to_clue_algorithm_name(algorithm_name)
    algorithm_name
  end
end

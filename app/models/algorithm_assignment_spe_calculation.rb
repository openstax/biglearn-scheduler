class AlgorithmAssignmentSpeCalculation < ApplicationRecord
  belongs_to :assignment_spe_calculation, primary_key: :uuid,
                                          foreign_key: :assignment_spe_calculation_uuid,
                                          inverse_of: :algorithm_assignment_spe_calculations

  scope :with_assignment_spe_calculation_attributes, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT algorithm_assignment_spe_calculations.*,
            assignment_spe_calculations.ecosystem_uuid,
            assignment_spe_calculations.assignment_uuid,
            assignment_spe_calculations.history_type,
            assignment_spe_calculations.k_ago,
            assignment_spe_calculations.book_container_uuid,
            assignment_spe_calculations.is_spaced,
            assignment_spe_calculations.student_uuid,
            assignment_spe_calculations.exercise_count
          FROM algorithm_assignment_spe_calculations
            INNER JOIN assignment_spe_calculations
            ON assignment_spe_calculations.uuid =
              algorithm_assignment_spe_calculations.assignment_spe_calculation_uuid
        ) AS algorithm_assignment_spe_calculations
      SQL
    )
  end

  validates :assignment_spe_calculation, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :assignment_spe_calculation_uuid }
end

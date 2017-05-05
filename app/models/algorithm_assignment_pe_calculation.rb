class AlgorithmAssignmentPeCalculation < ApplicationRecord
  belongs_to :assignment_pe_calculation, primary_key: :uuid,
                                         foreign_key: :assignment_pe_calculation_uuid,
                                         inverse_of: :algorithm_assignment_pe_calculations

  scope :with_assignment_pe_calculation_attributes, ->(wheres = nil) do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT algorithm_assignment_pe_calculations.*,
            assignment_pe_calculations.ecosystem_uuid,
            assignment_pe_calculations.assignment_uuid,
            assignment_pe_calculations.book_container_uuid,
            assignment_pe_calculations.student_uuid,
            assignment_pe_calculations.exercise_count
          FROM algorithm_assignment_pe_calculations
            INNER JOIN assignment_pe_calculations
              ON assignment_pe_calculations.uuid =
                algorithm_assignment_pe_calculations.assignment_pe_calculation_uuid
          #{"WHERE #{wheres.respond_to?(:to_sql) ? wheres.to_sql : wheres}" unless wheres.nil?}
        ) AS algorithm_assignment_pe_calculations
      SQL
    )
  end

  validates :assignment_pe_calculation, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :assignment_pe_calculation_uuid }
end

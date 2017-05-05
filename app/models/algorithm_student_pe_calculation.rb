class AlgorithmStudentPeCalculation < ApplicationRecord
  belongs_to :student_pe_calculation, primary_key: :uuid,
                                      foreign_key: :student_pe_calculation_uuid,
                                      inverse_of: :algorithm_student_pe_calculations

  scope :with_student_pe_calculation_attributes, ->(wheres = nil) do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT algorithm_student_pe_calculations.*,
            student_pe_calculations.clue_algorithm_name,
            student_pe_calculations.ecosystem_uuid,
            student_pe_calculations.book_container_uuid,
            student_pe_calculations.student_uuid,
            student_pe_calculations.exercise_count
          FROM algorithm_student_pe_calculations
            INNER JOIN student_pe_calculations
              ON student_pe_calculations.uuid =
                algorithm_student_pe_calculations.student_pe_calculation_uuid
          #{"WHERE #{wheres.respond_to?(:to_sql) ? wheres.to_sql : wheres}" unless wheres.nil?}
        ) AS algorithm_student_pe_calculations
      SQL
    )
  end

  validates :student_pe_calculation, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :student_pe_calculation_uuid }
end

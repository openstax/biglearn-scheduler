class AlgorithmStudentClueCalculation < ApplicationRecord
  belongs_to :student_clue_calculation, primary_key: :uuid,
                                        foreign_key: :student_clue_calculation_uuid,
                                        inverse_of: :algorithm_student_clue_calculations

  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  scope :with_student_clue_calculation_attributes_and_partitioned_rank, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT algorithm_student_clue_calculations.*,
            student_clue_calculations.ecosystem_uuid,
            student_clue_calculations.book_container_uuid,
            student_clue_calculations.student_uuid,
            row_number() OVER (
              PARTITION BY student_clue_calculations.student_uuid,
                 algorithm_student_clue_calculations.algorithm_name
              ORDER BY algorithm_student_clue_calculations.clue_value ASC,
                algorithm_student_clue_calculations.created_at ASC
            ) AS partitioned_rank
          FROM algorithm_student_clue_calculations
            INNER JOIN student_clue_calculations
            ON student_clue_calculations.uuid =
              algorithm_student_clue_calculations.student_clue_calculation_uuid
        ) AS algorithm_student_clue_calculations
      SQL
    )
  end

  validates :student_clue_calculation, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :student_clue_calculation_uuid }
  validates :clue_data, presence: true
  validates :clue_value, presence: true
end

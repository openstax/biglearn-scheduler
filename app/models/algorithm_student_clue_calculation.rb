class AlgorithmStudentClueCalculation < ApplicationRecord
  # https://blog.codeship.com/folding-postgres-window-functions-into-rails/
  scope :with_rank_by_student_and_algorithm, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT algorithm_student_clue_calculations.*,
            row_number() OVER (
              PARTITION BY algorithm_student_clue_calculations.student_uuid,
                 algorithm_student_clue_calculations.algorithm_name
              ORDER BY algorithm_student_clue_calculations.clue_value ASC,
                algorithm_student_clue_calculations.created_at ASC
            ) AS rank_by_student_and_algorithm
          FROM algorithm_student_clue_calculations
        ) AS algorithm_student_clue_calculations
      SQL
    )
  end

  validates :student_clue_calculation_uuid, presence: true
  validates :algorithm_name, presence: true,
                             uniqueness: { scope: :student_clue_calculation_uuid }
  validates :clue_data, presence: true
  validates :ecosystem_uuid, presence: true
  validates :book_container_uuid, presence: true
  validates :student_uuid, presence: true
  validates :clue_value, presence: true
end

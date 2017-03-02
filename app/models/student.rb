class Student < ApplicationRecord
  belongs_to :course, primary_key: :uuid, foreign_key: :course_uuid

  scope :with_recalculated_worst_clues, -> do
    joins(
      <<-SQL.strip_heredoc
        CROSS JOIN LATERAL (
          SELECT book_container_uuid recalculated_worst_clue_book_container_uuid,
                 value recalculated_worst_clue_value
          FROM student_clues
          WHERE student_clues.student_uuid = students.uuid
          ORDER BY student_clues.value
          LIMIT 1
        ) worst_clue
      SQL
    ).select('*')
  end

  scope :where_worst_clues_are_outdated, -> do
    with_recalculated_worst_clues.where(
      <<-SQL.strip_heredoc
        ( worst_clue_book_container_uuid IS NULL AND
          recalculated_worst_clue_book_container_uuid IS NOT NULL ) OR
        ( worst_clue_value IS NULL AND
          recalculated_worst_clue_book_container_uuid IS NOT NULL ) OR
        worst_clue_book_container_uuid != recalculated_worst_clue_book_container_uuid OR
        worst_clue_value != recalculated_worst_clue_value
      SQL
    )
  end

  validates :course_uuid,            presence: true
  validates :course_container_uuids, presence: true
end

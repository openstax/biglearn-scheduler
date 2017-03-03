class Student < ApplicationRecord
  belongs_to :course, primary_key: :uuid, foreign_key: :course_uuid

  scope :with_worst_clues, -> do
    joins(
      <<-SQL.strip_heredoc
        LEFT JOIN LATERAL (
          SELECT book_container_uuid worst_clue_book_container_uuid,
                 value worst_clue_value
          FROM student_clues
          WHERE student_clues.student_uuid = students.uuid
          ORDER BY student_clues.value
          LIMIT 1
        ) worst_clue
        ON true
      SQL
    ).select('*')
  end

  validates :course_uuid,            presence: true
  validates :course_container_uuids, presence: true
end

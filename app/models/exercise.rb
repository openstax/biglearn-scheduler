class Exercise < ApplicationRecord
  has_many :ecosystem_exercises, primary_key: :uuid,
                                 foreign_key: :exercise_uuid,
                                 inverse_of: :exercise,
                                 dependent: :destroy

  # This query uses a PostgreSQL 9.1 feature (Group by can guess some missing columns)
  # but could be rewritten to not depend on it if needed
  # https://wiki.postgresql.org/wiki/What%27s_new_in_PostgreSQL_9.1#SQL_and_PL.2FPgSQL_features
  scope :with_response_counts, ->(select: '"exercises".*') do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT #{select},
            COUNT("responses"."id") AS "response_count",
            COUNT("responses"."id") FILTER (
              WHERE "responses"."used_in_ecosystem_matrix_updates" = FALSE
            ) AS "new_response_count"
          FROM "exercises"
            LEFT OUTER JOIN "responses"
              ON "responses"."exercise_uuid" = "exercises"."uuid"
          GROUP BY "exercises"."id"
        ) AS "exercises"
      SQL
    )
  end

  validates :group_uuid, presence: true
  validates :version,    presence: true
end

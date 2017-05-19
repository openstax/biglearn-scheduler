class EcosystemExercise < ApplicationRecord
  # This query uses a PostgreSQL 9.1 feature but could be rewritten to not depend on it if needed
  # https://wiki.postgresql.org/wiki/What%27s_new_in_PostgreSQL_9.1#SQL_and_PL.2FPgSQL_features
  scope :with_response_counts, -> do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT "ecosystem_exercises".*,
            COUNT("responses"."id") AS "response_count",
            COUNT("responses"."id") FILTER (
              WHERE "responses"."used_in_ecosystem_matrix_updates" = FALSE
            ) AS "new_response_count"
          FROM "ecosystem_exercises"
            LEFT OUTER JOIN "responses"
              ON "responses"."exercise_uuid" = "ecosystem_exercises"."exercise_uuid"
                AND "responses"."ecosystem_uuid" = "ecosystem_exercises"."ecosystem_uuid"
          GROUP BY "ecosystem_exercises"."id"
        ) AS "ecosystem_exercises"
      SQL
    )
  end

  validates :ecosystem_uuid,       presence: true
  validates :exercise_uuid,        presence: true
  validates :exercise_group_uuid,  presence: true
  validates :book_container_uuids, presence: true
end

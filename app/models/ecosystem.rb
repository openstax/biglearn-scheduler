class Ecosystem < ApplicationRecord
  # This query uses a PostgreSQL 9.1 feature but could be rewritten to not depend on it if needed
  # https://wiki.postgresql.org/wiki/What%27s_new_in_PostgreSQL_9.1#SQL_and_PL.2FPgSQL_features
  scope :with_response_counts, ->(ids: nil) do
    from(
      <<-SQL.strip_heredoc
        (
          SELECT "ecosystems".*,
            COUNT("responses"."id") AS "response_count",
            COUNT("responses"."id") FILTER (
              WHERE "responses"."used_in_ecosystem_matrix_updates" = FALSE
            ) AS "new_response_count"
          FROM "ecosystems"
            LEFT OUTER JOIN "responses"
              ON "responses"."ecosystem_uuid" = "ecosystems"."uuid"
          #{"WHERE \"ecosystems\".\"id\" IN (#{ids.map { |id| "'#{id}'" }.join(', ')})}" \
            unless ids.nil?}
          GROUP BY "ecosystems"."id"
        ) AS "ecosystems"
      SQL
    )
  end

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

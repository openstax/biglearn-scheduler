class Exercise < ApplicationRecord
  has_many :ecosystem_exercises, primary_key: :uuid,
                                 foreign_key: :exercise_uuid,
                                 inverse_of: :exercise,
                                 dependent: :destroy

  has_many :responses, primary_key: :uuid,
                       foreign_key: :exercise_uuid,
                       inverse_of: :exercise

  # This query uses a PostgreSQL 9.1 feature (Group by can guess some missing columns)
  # but could be rewritten to not depend on it if needed
  # https://wiki.postgresql.org/wiki/What%27s_new_in_PostgreSQL_9.1#SQL_and_PL.2FPgSQL_features
  scope :with_new_response_ratio_above_threshold, ->(threshold:, limit: nil) do
    # The limit clause is written in raw SQL because Rails generates invalid SQL otherwise
    # (it adds a bind parameter to the SQL but fails to supply it at the end of the query)
    from(
      <<-FROM_SQL.strip_heredoc
        (
          #{
            left_outer_joins(:responses)
              .group(:id)
              .having(
                <<-HAVING_SQL.strip_heredoc
                  COUNT("responses"."id") FILTER (
                    WHERE "responses"."used_in_ecosystem_matrix_updates" = FALSE
                  ) > #{threshold} * COUNT("responses"."id")
                HAVING_SQL
              ).to_sql
          } #{"LIMIT #{limit}" unless limit.nil?}
        ) AS "exercises"
      FROM_SQL
    )
  end

  validates :group_uuid, presence: true
  validates :version,    presence: true
end

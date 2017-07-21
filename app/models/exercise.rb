class Exercise < ApplicationRecord
  has_many :ecosystem_exercises, primary_key: :uuid,
                                 foreign_key: :exercise_uuid,
                                 inverse_of: :exercise,
                                 dependent: :destroy

  has_many :responses, primary_key: :uuid,
                       foreign_key: :exercise_uuid,
                       inverse_of: :exercise

  def self.group_uuids_with_new_response_ratio_above_threshold(threshold:, limit: nil)
    joins(:responses)
      .where(
        <<-WHERE_SQL.strip_heredoc
          EXISTS (
            SELECT "responses".*
            FROM "responses"
            WHERE "responses"."exercise_uuid" = "exercises"."uuid"
              AND "responses"."used_in_ecosystem_matrix_updates" = FALSE
          )
        WHERE_SQL
      )
      .group(:group_uuid)
      .having(
        <<-HAVING_SQL.strip_heredoc
          COUNT("responses"."id") FILTER (
            WHERE "responses"."used_in_ecosystem_matrix_updates" = FALSE
          ) > #{threshold} * COUNT("responses"."id")
        HAVING_SQL
      )
      .limit(limit)
      .pluck(:group_uuid)
  end

  validates :group_uuid, presence: true
  validates :version,    presence: true
end

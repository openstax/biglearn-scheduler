class AddMetadataSequenceNumbersToEcosystemsAndCourses < ActiveRecord::Migration[5.0]
  def change
    add_column :ecosystems, :metadata_sequence_number, :integer

    Ecosystem.connection.execute(
      <<~CTE_SQL
        WITH "ecosystem_row_numbers" AS (
          SELECT "ecosystems"."id", ROW_NUMBER() OVER (
            ORDER BY "ecosystems"."created_at", "ecosystems"."id"
          ) AS "row_number"
          FROM "ecosystems"
        )
        UPDATE "ecosystems"
        SET "metadata_sequence_number" = "ecosystem_row_numbers"."row_number" - 1
        FROM "ecosystem_row_numbers"
        WHERE "ecosystem_row_numbers"."id" = "ecosystems"."id"
      CTE_SQL
    )

    change_column_null :ecosystems, :metadata_sequence_number, false
    add_index :ecosystems, :metadata_sequence_number, unique: true

    add_column :courses, :metadata_sequence_number, :integer

    Course.connection.execute(
      <<~CTE_SQL
        WITH "course_row_numbers" AS (
          SELECT "courses"."id", ROW_NUMBER() OVER (
            ORDER BY "courses"."created_at", "courses"."id"
          ) AS "row_number"
          FROM "courses"
        )
        UPDATE "courses"
        SET "metadata_sequence_number" = "course_row_numbers"."row_number" - 1
        FROM "course_row_numbers"
        WHERE "course_row_numbers"."id" = "courses"."id"
      CTE_SQL
    )

    change_column_null :courses, :metadata_sequence_number, false
    add_index :courses, :metadata_sequence_number, unique: true
  end
end

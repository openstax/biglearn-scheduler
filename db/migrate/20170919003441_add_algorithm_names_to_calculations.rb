class AddAlgorithmNamesToCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :ecosystem_matrix_updates,  :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :exercise_calculations,     :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :student_clue_calculations, :algorithm_names, :string,
                                           array: true, null: false, default: []
    add_column :teacher_clue_calculations, :algorithm_names, :string,
                                           array: true, null: false, default: []

    reversible do |dir|
      dir.up do
        EcosystemMatrixUpdate.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "algorithm_names" = (
              SELECT COALESCE(
                ARRAY_AGG("algorithm_ecosystem_matrix_updates"."algorithm_name"),
                ARRAY[]::varchar[]
              )
              FROM "algorithm_ecosystem_matrix_updates"
              WHERE "algorithm_ecosystem_matrix_updates"."ecosystem_matrix_update_uuid" =
                "ecosystem_matrix_updates"."uuid"
            )
          UPDATE_SQL
        )

        ExerciseCalculation.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "algorithm_names" = (
              SELECT COALESCE(
                ARRAY_AGG("algorithm_exercise_calculations"."algorithm_name"),
                ARRAY[]::varchar[]
              )
              FROM "algorithm_exercise_calculations"
              WHERE "algorithm_exercise_calculations"."exercise_calculation_uuid" =
                "exercise_calculations"."uuid"
            )
          UPDATE_SQL
        )

        StudentClueCalculation.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "algorithm_names" = (
              SELECT COALESCE(
                ARRAY_AGG("algorithm_student_clue_calculations"."algorithm_name"),
                ARRAY[]::varchar[]
              )
              FROM "algorithm_student_clue_calculations"
              WHERE "algorithm_student_clue_calculations"."student_clue_calculation_uuid" =
                "student_clue_calculations"."uuid"
            )
          UPDATE_SQL
        )

        TeacherClueCalculation.update_all(
          <<-UPDATE_SQL.strip_heredoc
            "algorithm_names" = (
              SELECT COALESCE(
                ARRAY_AGG("algorithm_teacher_clue_calculations"."algorithm_name"),
                ARRAY[]::varchar[]
              )
              FROM "algorithm_teacher_clue_calculations"
              WHERE "algorithm_teacher_clue_calculations"."teacher_clue_calculation_uuid" =
                "teacher_clue_calculations"."uuid"
            )
          UPDATE_SQL
        )
      end
    end

    add_index :ecosystem_matrix_updates,  :algorithm_names, using: :gin
    add_index :exercise_calculations,     :algorithm_names, using: :gin
    add_index :student_clue_calculations, :algorithm_names, using: :gin
    add_index :teacher_clue_calculations, :algorithm_names, using: :gin
  end
end

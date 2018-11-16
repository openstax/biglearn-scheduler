class ChangeIsUploadedToPending < ActiveRecord::Migration[5.0]
  def up
    add_column :algorithm_exercise_calculations, :is_pending_for_student, :boolean,
               null: false, default: true
    add_column :algorithm_exercise_calculations, :pending_assignment_uuids, :string, array: true

    AlgorithmExerciseCalculation.update_all(
      <<-UPDATE_SQL.strip_heredoc
        "is_pending_for_student" = NOT "is_uploaded_for_student",
        "pending_assignment_uuids" = ARRAY(
          SELECT "assignments"."uuid"::varchar
          FROM "assignments"
          INNER JOIN "exercise_calculations"
            ON "exercise_calculations"."student_uuid" = "assignments"."student_uuid"
            AND "exercise_calculations"."ecosystem_uuid" = "assignments"."ecosystem_uuid"
          WHERE "exercise_calculations"."uuid" =
            "algorithm_exercise_calculations"."exercise_calculation_uuid"
          EXCEPT
          SELECT UNNEST("is_uploaded_for_assignment_uuids")
        )
      UPDATE_SQL
    )

    add_index :algorithm_exercise_calculations, :is_pending_for_student
    add_index :algorithm_exercise_calculations, 'CARDINALITY("pending_assignment_uuids")',
              name: 'index_alg_ex_calc_on_cardinality_of_pending_assignment_uuids'

    change_column_null :algorithm_exercise_calculations, :pending_assignment_uuids, false

    remove_column :algorithm_exercise_calculations, :is_uploaded_for_student
    remove_column :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids
  end

  def down
    add_column :algorithm_exercise_calculations, :is_uploaded_for_student, :boolean
    add_column :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids, :string,
               array: true, null: false, default: []

    AlgorithmExerciseCalculation.update_all(
      <<-UPDATE_SQL.strip_heredoc
        "is_uploaded_for_student" = NOT "is_pending_for_student",
        "is_uploaded_for_assignment_uuids" = ARRAY(
          SELECT "assignments"."uuid"::varchar
          FROM "assignments"
          INNER JOIN "exercise_calculations"
            ON "exercise_calculations"."student_uuid" = "assignments"."student_uuid"
            AND "exercise_calculations"."ecosystem_uuid" = "assignments"."ecosystem_uuid"
          WHERE "exercise_calculations"."uuid" =
            "algorithm_exercise_calculations"."exercise_calculation_uuid"
          EXCEPT
          SELECT UNNEST("pending_assignment_uuids")
        )
      UPDATE_SQL
    )

    add_index :algorithm_exercise_calculations, :is_uploaded_for_student,
              name: 'index_alg_ex_calc_on_is_uploaded_for_student'
    add_index :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids, using: :gin,
              name: 'index_alg_ex_calc_on_is_uploaded_for_assignment_uuids'

    change_column_null :algorithm_exercise_calculations, :is_uploaded_for_student, false

    remove_column :algorithm_exercise_calculations, :is_pending_for_student
    remove_column :algorithm_exercise_calculations, :pending_assignment_uuids
  end
end

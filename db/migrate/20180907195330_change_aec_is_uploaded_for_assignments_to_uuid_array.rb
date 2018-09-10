class ChangeAecIsUploadedForAssignmentsToUuidArray < ActiveRecord::Migration[5.0]
  def up
    add_column :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids, :string,
               array: true, null: false, default: []

    AlgorithmExerciseCalculation.where(is_uploaded_for_assignments: true).update_all(
      <<-UPDATE_SQL.strip_heredoc
        "is_uploaded_for_assignment_uuids" = (
          SELECT ARRAY_AGG("assignments"."uuid")
          FROM "assignments"
          INNER JOIN "exercise_calculations"
            ON "exercise_calculations"."student_uuid" = "assignments"."student_uuid"
            AND "exercise_calculations"."ecosystem_uuid" = "assignments"."ecosystem_uuid"
          WHERE "exercise_calculations"."uuid" =
            "algorithm_exercise_calculations"."exercise_calculation_uuid"
        )
      UPDATE_SQL
    )

    add_index :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids, using: :gin,
              name: 'index_alg_ex_calc_on_is_uploaded_for_assignment_uuids'

    remove_column :algorithm_exercise_calculations, :is_uploaded_for_assignments

    change_column_null :algorithm_exercise_calculations, :is_uploaded_for_student, false
  end

  def down
    change_column_null :algorithm_exercise_calculations, :is_uploaded_for_student, true

    add_column :algorithm_exercise_calculations, :is_uploaded_for_assignments, :boolean

    AlgorithmExerciseCalculation.update_all(
      "is_uploaded_for_assignments = (is_uploaded_for_assignment_uuids != '{}')"
    )

    add_index :algorithm_exercise_calculations, :is_uploaded_for_assignments,
              name: 'index_alg_ex_calc_on_is_uploaded_for_assignments'

    remove_column :algorithm_exercise_calculations, :is_uploaded_for_assignment_uuids
  end
end

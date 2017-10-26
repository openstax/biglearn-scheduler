class AddUsedInEcosystemMatrixUpdatesToExerciseGroups < ActiveRecord::Migration[5.0]
  def change
    EcosystemExercise.where(next_ecosystem_matrix_update_response_count: nil)
                     .update_all(next_ecosystem_matrix_update_response_count: 0)
    change_column_null :ecosystem_exercises, :next_ecosystem_matrix_update_response_count, false

    add_column :exercise_groups, :used_in_ecosystem_matrix_updates, :boolean, null: false,
                                                                              default: true

    change_column_default :exercise_groups, :used_in_ecosystem_matrix_updates, from: true, to: nil

    ExerciseGroup.where(response_count: 0).update_all(used_in_ecosystem_matrix_updates: false)

    add_index :exercise_groups, :used_in_ecosystem_matrix_updates
  end
end

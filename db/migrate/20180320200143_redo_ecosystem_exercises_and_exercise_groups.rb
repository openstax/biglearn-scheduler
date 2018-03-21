class RedoEcosystemExercisesAndExerciseGroups < ActiveRecord::Migration[5.0]
  def up
    add_column :exercise_groups, :next_update_response_count, :integer

    change_column_null :exercise_groups, :next_update_response_count, false, 0

    rename_column :exercise_groups, :used_in_ecosystem_matrix_updates,
                                    :trigger_ecosystem_matrix_update

    ExerciseGroup.update_all(trigger_ecosystem_matrix_update: true)

    remove_column :ecosystem_exercises, :next_ecosystem_matrix_update_response_count
  end

  def down
    add_column :ecosystem_exercises, :next_ecosystem_matrix_update_response_count, :integer

    change_column_null :ecosystem_exercises, :next_ecosystem_matrix_update_response_count, false, 0

    add_index :ecosystem_exercises, :next_ecosystem_matrix_update_response_count,
              name: 'index_ecosystem_exercises_on_next_eco_mtx_upd_response_count'

    rename_column :exercise_groups, :trigger_ecosystem_matrix_update,
                                    :used_in_ecosystem_matrix_updates

    rename_column :exercise_groups, :next_update_response_count, :response_count

    ExerciseGroup.update_all(used_in_ecosystem_matrix_updates: false, response_count: 0)
  end
end

class AddNextEcosystemMatrixUpdateResponseCountIndexToEcosystemExercises < ActiveRecord::Migration[5.0]
  def change
    add_index :ecosystem_exercises, :next_ecosystem_matrix_update_response_count,
              name: 'index_ecosystem_exercises_on_next_eco_mtx_upd_response_count'
  end
end

class AddNextEcosystemMatrixUpdateResponseCountToEcosystemExercises < ActiveRecord::Migration[5.0]
  def change
    add_column :ecosystem_exercises, :next_ecosystem_matrix_update_response_count, :integer
  end
end

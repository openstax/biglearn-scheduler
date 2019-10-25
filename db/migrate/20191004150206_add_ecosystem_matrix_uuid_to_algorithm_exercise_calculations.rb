class AddEcosystemMatrixUuidToAlgorithmExerciseCalculations < ActiveRecord::Migration[5.2]
  def change
    add_column :algorithm_exercise_calculations, :ecosystem_matrix_uuid, :uuid
    change_column_null :algorithm_exercise_calculations,
                       :ecosystem_matrix_uuid,
                       false,
                       '00000000-0000-0000-0000-000000000000'
    add_index :algorithm_exercise_calculations, :ecosystem_matrix_uuid
  end
end

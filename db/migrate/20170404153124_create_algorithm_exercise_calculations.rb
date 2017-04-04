class CreateAlgorithmExerciseCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_exercise_calculations do |t|
      t.uuid   :uuid,                      null: false, index: { unique: true }
      t.uuid   :exercise_calculation_uuid, null: false
      t.citext :algorithm_name,            null: false
      t.uuid   :exercise_uuids,            null: false, array: true

      t.timestamps                         null: false
    end

    add_index :algorithm_exercise_calculations,
              [:exercise_calculation_uuid, :algorithm_name],
              unique: true,
              name: 'index_alg_ex_calcs_on_ex_calc_uuid_and_alg_name'
  end
end

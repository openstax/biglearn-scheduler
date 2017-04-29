class CreateAssignmentSpeCalculationExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_spe_calculation_exercises do |t|
      t.uuid :uuid,                            null: false, index: { unique: true }
      t.uuid :assignment_spe_calculation_uuid, null: false
      t.uuid :exercise_uuid,                   null: false, index: true

      t.timestamps                             null: false
    end

    add_index :assignment_spe_calculation_exercises,
              [ :assignment_spe_calculation_uuid, :exercise_uuid ],
              unique: true,
              name: 'index_a_spe_calc_ex_on_alg_a_spe_calc_uuid_and_ex_uuid'
  end
end

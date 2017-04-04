class CreateAlgorithmAssignmentSpeCalculationExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_assignment_spe_calculation_exercises do |t|
      t.uuid :uuid,                                      null: false, index: { unique: true }
      t.uuid :algorithm_assignment_spe_calculation_uuid, null: false
      t.uuid :exercise_uuid,                             null: false, index: {
        name: 'index_alg_a_spe_calc_ex_on_ex_uuid'
      }

      t.timestamps                                       null: false
    end

    add_index :algorithm_assignment_spe_calculation_exercises,
              [ :algorithm_assignment_spe_calculation_uuid, :exercise_uuid ],
              unique: true,
              name: 'index_alg_a_spe_calc_ex_on_alg_a_spe_calc_uuid_and_ex_uuid'
  end
end

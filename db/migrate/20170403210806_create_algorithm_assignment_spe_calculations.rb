class CreateAlgorithmAssignmentSpeCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_assignment_spe_calculations do |t|
      t.uuid    :uuid,                            null: false, index: { unique: true }
      t.uuid    :assignment_spe_calculation_uuid, null: false
      t.citext  :algorithm_name,                  null: false
      t.uuid    :assignment_uuid,                 null: false
      t.uuid    :student_uuid,                    null: false
      t.uuid    :exercise_uuids,                  null: false, array: true
      t.boolean :sent_to_api_server,              null: false, index: true

      t.timestamps                                null: false
    end

    add_index :algorithm_assignment_spe_calculations,
              [ :assignment_spe_calculation_uuid, :algorithm_name ],
              unique: true,
              name: 'index_alg_a_spe_calc_on_a_spe_calc_uuid_and_alg_name'
  end
end

class CreateAlgorithmAssignmentPeCalculations < ActiveRecord::Migration[5.0]
  def change
    enable_extension :citext

    create_table :algorithm_assignment_pe_calculations do |t|
      t.uuid   :uuid,                           null: false, index: { unique: true }
      t.uuid   :assignment_pe_calculation_uuid, null: false
      t.citext :algorithm_name,                 null: false
      t.uuid   :assignment_uuid,                null: false
      t.uuid   :student_uuid,                   null: false
      t.uuid   :exercise_uuids,                 null: false, array: true

      t.timestamps                              null: false
    end

    add_index :algorithm_assignment_pe_calculations,
              [ :assignment_pe_calculation_uuid, :algorithm_name ],
              unique: true,
              name: 'index_alg_a_pe_calc_on_a_pe_calc_uuid_and_alg_name'
  end
end

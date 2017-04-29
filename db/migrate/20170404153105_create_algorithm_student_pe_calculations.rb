class CreateAlgorithmStudentPeCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_student_pe_calculations do |t|
      t.uuid    :uuid,                        null: false, index: { unique: true }
      t.uuid    :student_pe_calculation_uuid, null: false
      t.citext  :algorithm_name,              null: false
      t.uuid    :exercise_uuids,              null: false, array: true
      t.boolean :is_uploaded,                 null: false, index: true

      t.timestamps                            null: false
    end

    add_index :algorithm_student_pe_calculations,
              [ :student_pe_calculation_uuid, :algorithm_name ],
              unique: true,
              name: 'index_alg_s_pe_calc_on_s_pe_calc_uuid_and_alg_name'
  end
end

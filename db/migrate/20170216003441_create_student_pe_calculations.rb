class CreateStudentPeCalculations < ActiveRecord::Migration[5.0]
  def change
    enable_extension :citext

    create_table :student_pe_calculations do |t|
      t.uuid    :uuid,                null: false, index: { unique: true }
      t.citext  :clue_algorithm_name, null: false
      t.uuid    :ecosystem_uuid,      null: false, index: true
      t.uuid    :book_container_uuid, null: false, index: true
      t.uuid    :student_uuid,        null: false
      t.uuid    :exercise_uuids,      null: false, array: true
      t.integer :exercise_count,      null: false

      t.timestamps                    null: false
    end

    add_index :student_pe_calculations,
              [ :student_uuid, :book_container_uuid, :clue_algorithm_name ],
              unique: true,
              name: 'index_s_pe_calc_on_s_uuid_and_bc_uuid_and_clue_alg_name'
  end
end

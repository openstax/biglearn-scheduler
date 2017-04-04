class CreateStudentClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :student_clue_calculations do |t|
      t.uuid :uuid,                null: false, index: { unique: true }
      t.uuid :ecosystem_uuid,      null: false, index: true
      t.uuid :book_container_uuid, null: false, index: true
      t.uuid :student_uuid,        null: false
      t.uuid :exercise_uuids,      null: false, array: true

      t.timestamps                 null: false
    end

    add_index :student_clue_calculations,
              [ :student_uuid, :book_container_uuid ],
              unique: true,
              name: 'index_s_clue_calc_on_s_uuid_and_bc_uuid'
  end
end

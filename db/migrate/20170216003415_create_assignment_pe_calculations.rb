class CreateAssignmentPeCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_pe_calculations do |t|
      t.uuid :uuid,                null: false, index: { unique: true }
      t.uuid :ecosystem_uuid,      null: false, index: true
      t.uuid :assignment_uuid,     null: false
      t.uuid :book_container_uuid, null: false, index: true
      t.uuid :student_uuid,        null: false, index: true
      t.uuid :exercise_uuids,      null: false, array: true

      t.timestamps                 null: false
    end

    add_index :assignment_pe_calculations,
              [ :assignment_uuid, :book_container_uuid ],
              unique: true,
              name: 'index_a_pe_calc_on_a_uuid_and_bc_uuid'
  end
end

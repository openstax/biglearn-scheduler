class CreateAssignmentSpes < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_spes do |t|
      t.uuid    :uuid,                null: false, index: { unique: true }
      t.uuid    :student_uuid,        null: false, index: true
      t.uuid    :assignment_uuid,     null: false, index: true
      t.integer :history_type,        null: false
      t.uuid    :exercise_uuid,       null: false
      t.uuid    :book_container_uuid,              index: true
      t.integer :k_ago

      t.timestamps                    null: false
    end

    add_index :assignment_spes,
              [ :exercise_uuid, :assignment_uuid, :history_type ],
              unique: true,
              name: 'index_assignment_spes_on_ex_uuid_and_assign_uuid_and_hist_type'
  end
end

class CreateStudentClues < ActiveRecord::Migration[5.0]
  def change
    create_table :student_clues do |t|
      t.uuid    :uuid,                null: false, index: { unique: true }
      t.uuid    :student_uuid,        null: false
      t.uuid    :book_container_uuid, null: false, index: true
      t.decimal :value,               null: false

      t.timestamps                    null: false
    end

    add_index :student_clues, [:student_uuid, :book_container_uuid], unique: true
  end
end

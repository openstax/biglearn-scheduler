class CreateStudents < ActiveRecord::Migration[5.0]
  def change
    create_table :students do |t|
      t.uuid    :uuid,                           null: false, index: { unique: true }
      t.uuid    :course_uuid,                    null: false, index: true
      t.uuid    :course_container_uuids,         null: false, array: true
      t.uuid    :worst_clue_book_container_uuid
      t.decimal :worst_clue_value

      t.timestamps                               null: false
    end
  end
end

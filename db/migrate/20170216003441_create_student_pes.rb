class CreateStudentPes < ActiveRecord::Migration[5.0]
  def change
    create_table :student_pes do |t|
      t.uuid :uuid,                null: false, index: { unique: true }
      t.uuid :book_container_uuid, null: false, index: true
      t.uuid :student_uuid,        null: false, index: true
      t.uuid :exercise_uuid,       null: false

      t.timestamps                 null: false
    end

    add_index :student_pes, [:exercise_uuid, :student_uuid], unique: true
  end
end

class CreateAssignmentPes < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_pes do |t|
      t.uuid :uuid,            null: false, index: { unique: true }
      t.uuid :student_uuid,    null: false, index: true
      t.uuid :assignment_uuid, null: false, index: true
      t.uuid :exercise_uuid,   null: false

      t.timestamps             null: false
    end

    add_index :assignment_pes, [:exercise_uuid, :assignment_uuid], unique: true
  end
end

class CreateAssignmentSpes < ActiveRecord::Migration
  def change
    create_table :assignment_spes do |t|
      t.uuid :uuid,            null: false, index: { unique: true }
      t.uuid :assignment_uuid, null: false, index: true
      t.uuid :exercise_uuid,   null: false
      t.uuid :student_uuid,    null: false, index: true

      t.timestamps             null: false
    end

    add_index :assignment_spes, [:exercise_uuid, :assignment_uuid], unique: true
  end
end

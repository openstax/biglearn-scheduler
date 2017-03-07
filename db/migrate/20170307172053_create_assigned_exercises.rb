class CreateAssignedExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :assigned_exercises do |t|
      t.uuid :uuid,            null: false, index: { unique: true }
      t.uuid :assignment_uuid, null: false, index: true

      t.timestamps             null: false
    end
  end
end

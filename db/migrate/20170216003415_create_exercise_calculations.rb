class CreateExerciseCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :exercise_calculations do |t|
      t.uuid :uuid,           null: false, index: { unique: true }
      t.uuid :ecosystem_uuid, null: false, index: true
      t.uuid :student_uuid,   null: false

      t.timestamps            null: false
    end

    add_index :exercise_calculations, [ :student_uuid, :ecosystem_uuid ], unique: true
  end
end

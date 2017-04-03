class CreateExerciseCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :exercise_calculations do |t|
      t.uuid    :uuid,                   null: false, index: { unique: true }
      t.uuid    :algorithm_uuid,         null: false
      t.boolean :is_calculated,          null: false
      t.uuid    :exercise_uuids,         null: false, array: true
      t.uuid    :student_uuids,          null: false, array: true
      t.uuid    :ordered_exercise_uuids, null: false, array: true

      t.timestamps
    end

    add_index :exercise_calculations, [ :algorithm_uuid, :is_calculated ]
  end
end

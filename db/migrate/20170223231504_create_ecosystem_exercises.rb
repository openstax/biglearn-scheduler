class CreateEcosystemExercises < ActiveRecord::Migration
  def change
    create_table :ecosystem_exercises do |t|
      t.uuid :uuid,                 null: false, index: { unique: true }
      t.uuid :exercise_uuid,        null: false
      t.uuid :ecosystem_uuid,       null: false, index: true
      t.uuid :book_container_uuids, null: false, array: true

      t.timestamps                  null: false
    end

    add_index :ecosystem_exercises, [:exercise_uuid, :ecosystem_uuid], unique: true
  end
end

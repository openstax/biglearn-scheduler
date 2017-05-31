class CreateEcosystemExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :ecosystem_exercises do |t|
      t.uuid :uuid,                 null: false, index: { unique: true }
      t.uuid :ecosystem_uuid,       null: false, index: true
      t.uuid :exercise_uuid,        null: false
      t.uuid :book_container_uuids, null: false, array: true

      t.timestamps                  null: false
    end

    add_index :ecosystem_exercises,
              [ :exercise_uuid, :ecosystem_uuid ],
              unique: true,
              name: 'index_eco_exercises_on_exercise_uuid_and_eco_uuid'
  end
end

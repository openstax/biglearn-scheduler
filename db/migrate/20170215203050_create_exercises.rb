class CreateExercises < ActiveRecord::Migration
  def change
    create_table :exercises do |t|
      t.uuid    :uuid,                null: false, index: { unique: true }
      t.uuid    :exercise_uuid,       null: false, index: true
      t.uuid    :group_uuid,          null: false
      t.integer :version,             null: false
      t.uuid    :exercise_pool_uuids, null: false, array: true

      t.timestamps                    null: false
    end

    add_index :exercises, [:group_uuid, :version]
  end
end

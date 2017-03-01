class CreateExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :exercises do |t|
      t.uuid    :uuid,       null: false, index: { unique: true }
      t.uuid    :group_uuid, null: false
      t.integer :version,    null: false

      t.timestamps           null: false
    end

    add_index :exercises, [:group_uuid, :version]
  end
end

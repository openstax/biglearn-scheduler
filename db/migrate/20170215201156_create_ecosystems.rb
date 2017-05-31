class CreateEcosystems < ActiveRecord::Migration[5.0]
  def change
    create_table :ecosystems do |t|
      t.uuid    :uuid,            null: false, index: { unique: true }
      t.integer :sequence_number, null: false
      t.uuid    :exercise_uuids,  null: false, array: true

      t.timestamps                null: false
    end
  end
end

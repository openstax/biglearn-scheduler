class CreateEcosystemMatrixUpdates < ActiveRecord::Migration[5.0]
  def change
    create_table :ecosystem_matrix_updates do |t|
      t.uuid    :uuid,           null: false, index: { unique: true }
      t.uuid    :algorithm_uuid, null: false
      t.boolean :is_updated,     null: false
      t.uuid    :ecosystem_uuid, null: false, index: true

      t.timestamps               null: false
    end

    add_index :ecosystem_matrix_updates, [ :algorithm_uuid, :is_updated ]
  end
end

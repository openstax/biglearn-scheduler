class CreateEcosystemMatrixUpdates < ActiveRecord::Migration[5.0]
  def change
    enable_extension :citext

    create_table :ecosystem_matrix_updates do |t|
      t.uuid    :uuid,           null: false, index: { unique: true }
      t.citext  :algorithm_name, null: false
      t.boolean :is_updated,     null: false
      t.uuid    :ecosystem_uuid, null: false, index: true

      t.timestamps               null: false
    end

    add_index :ecosystem_matrix_updates, [ :algorithm_name, :is_updated ]
  end
end

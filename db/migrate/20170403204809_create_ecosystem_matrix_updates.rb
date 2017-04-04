class CreateEcosystemMatrixUpdates < ActiveRecord::Migration[5.0]
  def change
    create_table :ecosystem_matrix_updates do |t|
      t.uuid :uuid,           null: false, index: { unique: true }
      t.uuid :ecosystem_uuid, null: false, index: true

      t.timestamps            null: false
    end
  end
end

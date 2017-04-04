class CreateAlgorithmEcosystemMatrixUpdates < ActiveRecord::Migration[5.0]
  def change
    enable_extension :citext

    create_table :algorithm_ecosystem_matrix_updates do |t|
      t.uuid   :uuid,                         null: false, index: { unique: true }
      t.uuid   :ecosystem_matrix_update_uuid, null: false
      t.citext :algorithm_name,               null: false

      t.timestamps                            null: false
    end

    add_index :algorithm_ecosystem_matrix_updates,
              [:ecosystem_matrix_update_uuid, :algorithm_name],
              unique: true,
              name: 'index_alg_eco_mat_upds_on_eco_mat_upd_uuid_and_alg_name'
  end
end

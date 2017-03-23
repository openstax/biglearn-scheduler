class CreateBookContainerMappings < ActiveRecord::Migration[5.0]
  def change
    create_table :book_container_mappings do |t|
      t.uuid :uuid,                     null: false, index: { unique: true }
      t.uuid :from_ecosystem_uuid,      null: false, index: true
      t.uuid :to_ecosystem_uuid,        null: false, index: true
      t.uuid :from_book_container_uuid, null: false
      t.uuid :to_book_container_uuid,   null: false, index: true

      t.timestamps                      null: false
    end

    add_index :book_container_mappings,
              [ :from_book_container_uuid, :from_ecosystem_uuid, :to_ecosystem_uuid ],
              unique: true,
              name: 'index_bcms_on_from_bc_uuid_from_eco_uuid_to_eco_uuid_unique'
  end
end

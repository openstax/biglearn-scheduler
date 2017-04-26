class CreateAssignmentSpeCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_spe_calculations do |t|
      t.uuid    :uuid,                null: false, index: { unique: true }
      t.uuid    :ecosystem_uuid,      null: false, index: true
      t.uuid    :assignment_uuid,     null: false
      t.integer :history_type,        null: false
      t.integer :k_ago,               null: false
      t.uuid    :book_container_uuid,              index: true
      t.boolean :is_spaced,           null: false
      t.uuid    :student_uuid,        null: false, index: true
      t.uuid    :exercise_uuids,      null: false, array: true
      t.integer :exercise_count,      null: false

      t.timestamps                    null: false
    end

    add_index :assignment_spe_calculations,
              [ :assignment_uuid, :book_container_uuid, :k_ago, :history_type, :is_spaced ],
              unique: true,
              name: 'index_a_spe_calc_on_a_uuid_bc_uuid_k_ago_h_type_i_s'

    add_index :assignment_spe_calculations,
              [ :assignment_uuid, :k_ago, :history_type, :is_spaced ],
              unique: true,
              where: 'book_container_uuid IS NULL',
              name: 'index_a_spe_calc_on_a_uuid_k_ago_h_type_i_s_where_bc_uuid_null'
  end
end

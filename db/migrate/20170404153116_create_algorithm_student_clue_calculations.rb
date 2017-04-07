class CreateAlgorithmStudentClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_student_clue_calculations do |t|
      t.uuid    :uuid,                          null: false, index: { unique: true }
      t.uuid    :student_clue_calculation_uuid, null: false
      t.citext  :algorithm_name,                null: false
      t.jsonb   :clue_data,                     null: false
      t.boolean :is_uploaded,                   null: false, index: true
      t.uuid    :ecosystem_uuid,                null: false, index: true
      t.uuid    :book_container_uuid,           null: false, index: {
        name: 'index_alg_s_clue_calc_on_bc_uuid'
      }
      t.uuid    :student_uuid,                  null: false
      t.decimal :clue_value,                    null: false

      t.timestamps                              null: false
    end

    add_index :algorithm_student_clue_calculations,
              [ :student_clue_calculation_uuid, :algorithm_name ],
              unique: true,
              name: 'index_alg_s_clue_calc_on_s_clue_calc_uuid_and_alg_name'

    add_index :algorithm_student_clue_calculations,
              [ :student_uuid, :clue_value ],
              name: 'index_alg_s_clue_calc_on_s_uuid_and_clue_val'
  end
end

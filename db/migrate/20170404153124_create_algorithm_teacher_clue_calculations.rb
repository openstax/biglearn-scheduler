class CreateAlgorithmTeacherClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_teacher_clue_calculations do |t|
      t.uuid    :uuid,                          null: false, index: { unique: true }
      t.uuid    :teacher_clue_calculation_uuid, null: false
      t.citext  :algorithm_name,                null: false
      t.jsonb   :clue_data,                     null: false
      t.boolean :sent_to_api_server,            null: false, index: true

      t.timestamps                              null: false
    end

    add_index :algorithm_teacher_clue_calculations,
              [ :teacher_clue_calculation_uuid, :algorithm_name ],
              unique: true,
              name: 'index_alg_t_clue_calc_on_t_clue_calc_uuid_and_alg_name'
  end
end

class CreateAlgorithmClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :algorithm_clue_calculations do |t|
      t.uuid   :uuid,                  null: false, index: { unique: true }
      t.uuid   :clue_calculation_uuid, null: false
      t.citext :algorithm_name,        null: false
      t.jsonb  :clue_data,             null: false

      t.timestamps                     null: false
    end

    add_index :algorithm_clue_calculations,
              [:clue_calculation_uuid, :algorithm_name],
              unique: true,
              name: 'index_alg_clue_calcs_on_clue_calc_uuid_and_alg_name'
  end
end

class CreateAssignmentSpes < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_spes do |t|
      t.uuid    :uuid,                                null: false, index: { unique: true }
      t.uuid    :algorithm_exercise_calculation_uuid, null: false, index: true
      t.uuid    :assignment_uuid,                     null: false
      t.uuid    :exercise_uuid,                                    index: true
      t.integer :history_type,                        null: false, index: true

      t.timestamps                                    null: false
    end

    add_index :assignment_spes,
              [
                :assignment_uuid,
                :algorithm_exercise_calculation_uuid,
                :history_type,
                :exercise_uuid
              ],
              unique: true,
              name: 'index_a_spes_on_a_uuid_alg_ex_calc_uuid_h_type_and_ex_uuid'
    add_index :assignment_spes,
              [ :assignment_uuid, :algorithm_exercise_calculation_uuid, :history_type ],
              where: '"exercise_uuid" IS NULL',
              unique: true,
              name: 'index_a_spes_on_a_uuid_alg_ex_calc_uuid_and_h_type'
  end
end

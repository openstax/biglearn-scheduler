class CreateAssignmentPes < ActiveRecord::Migration[5.0]
  def change
    create_table :assignment_pes do |t|
      t.uuid :uuid,                                null: false, index: { unique: true }
      t.uuid :algorithm_exercise_calculation_uuid, null: false, index: true
      t.uuid :assignment_uuid,                     null: false
      t.uuid :exercise_uuid,                       null: false, index: true

      t.timestamps                                 null: false
    end

    add_index :assignment_pes,
              [ :assignment_uuid, :algorithm_exercise_calculation_uuid, :exercise_uuid ],
              unique: true,
              name: 'index_a_pes_on_a_uuid_alg_ex_calc_uuid_and_ex_uuid'
  end
end

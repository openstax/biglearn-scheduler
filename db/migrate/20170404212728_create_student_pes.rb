class CreateStudentPes < ActiveRecord::Migration[5.0]
  def change
    create_table :student_pes do |t|
      t.uuid :uuid,                                null: false, index: { unique: true }
      t.uuid :algorithm_exercise_calculation_uuid, null: false
      t.uuid :exercise_uuid,                                    index: true

      t.timestamps                                 null: false
    end

    add_index :student_pes,
              [ :algorithm_exercise_calculation_uuid, :exercise_uuid ],
              unique: true,
              name: 'index_s_pes_on_alg_ex_calc_uuid_and_ex_uuid'
    add_index :student_pes,
              :algorithm_exercise_calculation_uuid,
              where: '"exercise_uuid" IS NULL',
              unique: true
  end
end

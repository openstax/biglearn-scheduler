class CreateStudentPeCalculationExercises < ActiveRecord::Migration[5.0]
  def change
    create_table :student_pe_calculation_exercises do |t|
      t.uuid :uuid,                        null: false, index: { unique: true }
      t.uuid :student_pe_calculation_uuid, null: false
      t.uuid :exercise_uuid,               null: false, index: true

      t.timestamps                         null: false
    end

    add_index :student_pe_calculation_exercises,
              [ :student_pe_calculation_uuid, :exercise_uuid ],
              unique: true,
              name: 'index_s_pe_calc_ex_on_alg_s_pe_calc_uuid_and_ex_uuid'
  end
end

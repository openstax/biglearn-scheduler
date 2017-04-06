class CreateTeacherClueCalculations < ActiveRecord::Migration[5.0]
  def change
    create_table :teacher_clue_calculations do |t|
      t.uuid :uuid,                  null: false, index: { unique: true }
      t.uuid :ecosystem_uuid,        null: false, index: true
      t.uuid :book_container_uuid,   null: false, index: true
      t.uuid :course_container_uuid, null: false
      t.uuid :student_uuids,         null: false, array: true
      t.uuid :exercise_uuids,        null: false, array: true
      t.uuid :response_uuids,        null: false, array: true

      t.timestamps                   null: false
    end

    add_index :teacher_clue_calculations,
              [ :course_container_uuid, :book_container_uuid ],
              unique: true,
              name: 'index_t_clue_calc_on_cc_uuid_and_bc_uuid'
  end
end

class CreateAssignments < ActiveRecord::Migration[5.0]
  def change
    create_table :assignments do |t|
      t.uuid     :uuid,                          null: false, index: { unique: true }
      t.uuid     :course_uuid,                   null: false, index: true
      t.uuid     :ecosystem_uuid,                null: false, index: true
      t.uuid     :student_uuid,                  null: false, index: true
      t.string   :assignment_type,               null: false
      t.datetime :opens_at,                                   index: true
      t.datetime :due_at
      t.datetime :feedback_at,                                index: true
      t.uuid     :assigned_book_container_uuids, null: false, array: true
      t.uuid     :assigned_exercise_uuids,       null: false, array: true
      t.integer  :goal_num_tutor_assigned_spes,               index: true
      t.boolean  :spes_are_assigned,             null: false, index: true
      t.integer  :goal_num_tutor_assigned_pes,                index: true
      t.boolean  :pes_are_assigned,              null: false, index: true

      t.timestamps                               null: false
    end

    add_index :assignments, [ :due_at, :opens_at, :created_at ]
  end
end

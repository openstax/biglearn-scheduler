class CreateAssignments < ActiveRecord::Migration[5.0]
  def change
    create_table :assignments do |t|
      t.uuid     :uuid,                          null: false, index: { unique: true }
      t.uuid     :course_uuid,                   null: false, index: true
      t.uuid     :ecosystem_uuid,                null: false, index: true
      t.uuid     :student_uuid,                  null: false, index: true
      t.string   :assignment_type,               null: false
      t.datetime :opens_at
      t.datetime :due_at
      t.uuid     :assigned_book_container_uuids, null: false, array: true
      t.uuid     :assigned_exercise_uuids,       null: false, array: true
      t.integer  :goal_num_tutor_assigned_spes,  null: false
      t.boolean  :spes_are_assigned,             null: false
      t.integer  :goal_num_tutor_assigned_pes,   null: false
      t.boolean  :pes_are_assigned,              null: false

      t.timestamps                               null: false
    end

    add_index :assignments, [:due_at, :opens_at, :created_at]
    add_index :assignments, [:goal_num_tutor_assigned_spes, :spes_are_assigned],
              name: 'index_assignments_on_goal_num_spes_and_spes_are_assigned'
    add_index :assignments, [:goal_num_tutor_assigned_pes, :pes_are_assigned],
              name: 'index_assignments_on_goal_num_pes_and_pes_are_assigned'
  end
end

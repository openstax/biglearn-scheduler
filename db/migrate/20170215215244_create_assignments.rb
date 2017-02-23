class CreateAssignments < ActiveRecord::Migration
  def change
    create_table :assignments do |t|
      t.uuid    :uuid,                          null: false, index: { unique: true }
      t.uuid    :course_uuid,                   null: false, index: true
      t.uuid    :ecosystem_uuid,                null: false, index: true
      t.uuid    :student_uuid,                  null: false, index: true
      t.string  :assignment_type,               null: false
      t.uuid    :assigned_book_container_uuids, null: false, array: true
      t.uuid    :assigned_exercise_uuids,       null: false, array: true
      t.integer :goal_num_tutor_assigned_spes,  null: false, index: true
      t.boolean :spes_are_assigned,             null: false
      t.integer :goal_num_tutor_assigned_pes,   null: false, index: true
      t.boolean :pes_are_assigned,              null: false

      t.timestamps                              null: false
    end
  end
end

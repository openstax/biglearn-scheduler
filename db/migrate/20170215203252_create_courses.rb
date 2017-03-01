class CreateCourses < ActiveRecord::Migration[5.0]
  def change
    create_table :courses do |t|
      t.uuid    :uuid,                                 null: false, index: { unique: true }
      t.integer :sequence_number,                      null: false
      t.uuid    :ecosystem_uuid,                       null: false, index: true
      t.uuid    :course_excluded_exercise_uuids,       null: false, array: true
      t.uuid    :course_excluded_exercise_group_uuids, null: false, array: true
      t.uuid    :global_excluded_exercise_uuids,       null: false, array: true
      t.uuid    :global_excluded_exercise_group_uuids, null: false, array: true

      t.timestamps                                     null: false
    end
  end
end

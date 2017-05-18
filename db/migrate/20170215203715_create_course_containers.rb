class CreateCourseContainers < ActiveRecord::Migration[5.0]
  def change
    create_table :course_containers do |t|
      t.uuid    :uuid,          null: false, index: { unique: true }
      t.uuid    :course_uuid,   null: false
      t.uuid    :student_uuids, null: false, array: true

      t.timestamps              null: false
    end
  end
end

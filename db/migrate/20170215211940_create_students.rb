class CreateStudents < ActiveRecord::Migration[5.0]
  def change
    create_table :students do |t|
      t.uuid    :uuid,                   null: false, index: { unique: true }
      t.uuid    :course_uuid,            null: false, index: true
      t.uuid    :course_container_uuids, null: false, array: true
      t.boolean :pes_are_assigned,       null: false

      t.timestamps                       null: false
    end
  end
end

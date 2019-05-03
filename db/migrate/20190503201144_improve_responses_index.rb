class ImproveResponsesIndex < ActiveRecord::Migration[5.0]
  def change
    remove_index :responses, :student_uuid

    add_index :responses, [ :student_uuid, :exercise_uuid ]
  end
end

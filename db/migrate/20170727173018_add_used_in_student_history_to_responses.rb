class AddUsedInStudentHistoryToResponses < ActiveRecord::Migration[5.0]
  def change
    add_column :responses, :used_in_student_history, :boolean, null: false, default: false

    change_column_default :responses, :used_in_student_history, from: false, to: nil

    add_index :responses, :used_in_student_history
  end
end

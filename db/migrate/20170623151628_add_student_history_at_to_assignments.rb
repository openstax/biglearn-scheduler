class AddStudentHistoryAtToAssignments < ActiveRecord::Migration[5.0]
  def change
    add_column :assignments, :student_history_at, :datetime

    add_index :assignments, :student_history_at
  end
end

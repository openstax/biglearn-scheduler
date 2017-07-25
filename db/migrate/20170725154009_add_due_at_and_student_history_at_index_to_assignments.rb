class AddDueAtAndStudentHistoryAtIndexToAssignments < ActiveRecord::Migration[5.0]
  def change
    add_index :assignments, [ :due_at, :student_history_at ]
  end
end

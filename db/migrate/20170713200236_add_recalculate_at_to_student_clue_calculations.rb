class AddRecalculateAtToStudentClueCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :student_clue_calculations, :recalculate_at, :datetime

    add_index :student_clue_calculations, :recalculate_at
  end
end

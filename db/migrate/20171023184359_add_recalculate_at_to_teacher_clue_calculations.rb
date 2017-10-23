class AddRecalculateAtToTeacherClueCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :teacher_clue_calculations, :recalculate_at, :datetime

    add_index :teacher_clue_calculations, :recalculate_at
  end
end

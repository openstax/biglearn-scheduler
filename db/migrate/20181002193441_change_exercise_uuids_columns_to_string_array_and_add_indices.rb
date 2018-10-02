class ChangeExerciseUuidsColumnsToStringArrayAndAddIndices < ActiveRecord::Migration[5.0]
  def change
    change_column :student_clue_calculations, :exercise_uuids, :string, array: true
    add_index :student_clue_calculations, :exercise_uuids, using: :gin

    change_column :teacher_clue_calculations, :exercise_uuids, :string, array: true
    add_index :teacher_clue_calculations, :exercise_uuids, using: :gin
  end
end

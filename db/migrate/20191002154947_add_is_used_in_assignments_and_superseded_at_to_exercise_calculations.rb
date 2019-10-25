class AddIsUsedInAssignmentsAndSupersededAtToExerciseCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :exercise_calculations, :is_used_in_assignments, :boolean
    add_column :exercise_calculations, :superseded_at, :datetime

    remove_index :exercise_calculations, column: [ :student_uuid, :ecosystem_uuid ], unique: true

    change_column_null :exercise_calculations, :is_used_in_assignments, false, false

    add_index :exercise_calculations, [ :student_uuid, :ecosystem_uuid ]
    add_index :exercise_calculations, :superseded_at,
              where: 'NOT "is_used_in_assignments"',
              name: :index_deletable_exercise_calculations_on_superseded_at

    rename_column :responses, :used_in_clue_calculations, :is_used_in_clue_calculations
    rename_column :responses, :used_in_exercise_calculations, :is_used_in_exercise_calculations
    rename_column :responses, :used_in_response_count, :is_used_in_response_count
    rename_column :responses, :used_in_student_history, :is_used_in_student_history
  end
end

class AddAssignmentUuidsToAlgorithmExerciseCalculations < ActiveRecord::Migration[5.0]
  def change
    add_column :algorithm_exercise_calculations, :assignment_uuids, :uuid, array: true
  end
end

class IndexAssignedExercisesOnExerciseUuid < ActiveRecord::Migration[5.2]
  def change
    add_index :assigned_exercises, :exercise_uuid
  end
end

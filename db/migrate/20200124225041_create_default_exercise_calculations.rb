class CreateDefaultExerciseCalculations < ActiveRecord::Migration[5.2]
  def up
    exercise_calculations = []
    Ecosystem.where(Ecosystem.arel_table[:sequence_number].gt 0).find_each do |ecosystem|
      exercise_calculations << ExerciseCalculation.default.new(
        uuid: ecosystem.uuid,
        ecosystem_uuid: ecosystem.uuid,
        is_used_in_assignments: true
      )
    end

    ExerciseCalculation.import(
      exercise_calculations, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    ) unless exercise_calculations.empty?
  end

  def down
    ExerciseCalculation.default.delete_all
  end
end

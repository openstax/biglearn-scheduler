class CreateDefaultExerciseCalculations < ActiveRecord::Migration[5.2]
  def change
    exercise_calculations = Ecosystem.where(
      Ecosystem.arel_table[:sequence_number].gt 0
    ).in_batches.map do |ecosystem|
      ExerciseCalculation.new(
        uuid: ecosystem.uuid,
        ecosystem_uuid: ecosystem.uuid,
        student_uuid: '00000000-0000-0000-0000-000000000000',
        is_used_in_assignments: true
      )
    end

    ExerciseCalculation.import(
      exercise_calculations, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    )
  end

  def down
    ExerciseCalculation.where(student_uuid: '00000000-0000-0000-0000-000000000000').delete_all
  end
end

class Services::UpdateExerciseCalculations::Service
  def process(exercise_calculation_updates:)
    algorithm_exercise_calculations =
      exercise_calculation_updates.map do |exercise_calculation_update|
      AlgorithmExerciseCalculation.new(
        uuid: SecureRandom.uuid,
        exercise_calculation_uuid: exercise_calculation_update.fetch(:calculation_uuid),
        algorithm_name: exercise_calculation_update.fetch(:algorithm_name),
        exercise_uuids: exercise_calculation_update.fetch(:exercise_uuids)
      )
    end

    AlgorithmExerciseCalculation.import(
      algorithm_exercise_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :exercise_calculation_uuid, :algorithm_name ],
        columns: [ :exercise_uuids ]
      }
    )
  end
end

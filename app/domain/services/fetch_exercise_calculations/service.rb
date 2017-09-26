class Services::FetchExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 10

  def process(algorithm_name:)
    sanitized_algorithm_name = AlgorithmExerciseCalculation.sanitize(algorithm_name.downcase)

    exercise_calculations = ExerciseCalculation
      .with_exercise_uuids
      .where.not("\"algorithm_names\" @> ARRAY[#{sanitized_algorithm_name}]::varchar[]")
      .take(BATCH_SIZE)

    exercise_calculation_responses = exercise_calculations.map do |exercise_calculation|
      {
        calculation_uuid: exercise_calculation.uuid,
        ecosystem_uuid: exercise_calculation.ecosystem_uuid,
        student_uuid: exercise_calculation.student_uuid,
        exercise_uuids: exercise_calculation.exercise_uuids
      }
    end

    { exercise_calculations: exercise_calculation_responses }
  end
end

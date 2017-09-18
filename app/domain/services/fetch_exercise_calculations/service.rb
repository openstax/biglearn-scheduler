class Services::FetchExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 10

  def process(algorithm_name:)
    sanitized_algorithm_name = AlgorithmExerciseCalculation.sanitize algorithm_name

    exercise_calculations = ExerciseCalculation.transaction do
      # Extra memory is required to perform the hash anti-join efficiently
      ExerciseCalculation.connection.execute 'SET LOCAL work_mem=20480'

      ExerciseCalculation.with_exercise_uuids.where.not(
        AlgorithmExerciseCalculation.where(
          <<-WHERE_SQL.strip_heredoc
            "algorithm_exercise_calculations"."exercise_calculation_uuid" =
              "exercise_calculations"."uuid"
              AND "algorithm_exercise_calculations"."algorithm_name" = #{sanitized_algorithm_name}
          WHERE_SQL
        ).exists
      ).take(BATCH_SIZE)
    end

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

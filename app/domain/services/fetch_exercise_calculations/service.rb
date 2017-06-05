class Services::FetchExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 10

  def process(algorithm_name:)
    ec = ExerciseCalculation.arel_table
    aec = AlgorithmExerciseCalculation.arel_table
    aec_query = aec[:exercise_calculation_uuid].eq(ec[:uuid]).and(
      aec[:algorithm_name].eq(algorithm_name)
    )
    aec_join = "LEFT OUTER JOIN algorithm_exercise_calculations ON #{aec_query.to_sql}"
    exercise_calculations = ExerciseCalculation
                              .with_exercise_uuids
                              .joins(aec_join)
                              .where(algorithm_exercise_calculations: {id: nil})
                              .limit(BATCH_SIZE)

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

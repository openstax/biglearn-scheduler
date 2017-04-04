class Services::FetchExerciseCalculations::Service
  def process(algorithm_name:)
    algorithm_exercise_calculation_uuids =
      AlgorithmExerciseCalculation.where(algorithm_name: algorithm_name)
                                  .pluck(:exercise_calculation_uuid)
    exercise_calculations =
      ExerciseCalculation.where.not(uuid: algorithm_exercise_calculation_uuids).limit(1000)

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

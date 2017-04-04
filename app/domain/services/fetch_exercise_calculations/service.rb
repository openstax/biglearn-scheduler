class Services::FetchExerciseCalculations::Service
  def process(algorithm_name:)
    exercise_calculations = ExerciseCalculation.where(algorithm_name: algorithm_name,
                                                      is_calculated: false)
                                               .limit(1000)

    exercise_calculation_responses = exercise_calculations.map do |exercise_calculation|
      {
        calculation_uuid: exercise_calculation.uuid,
        exercise_uuids: exercise_calculation.exercise_uuids,
        student_uuids: exercise_calculation.student_uuids,
        ecosystem_uuid: exercise_calculation.ecosystem_uuid
      }
    end

    { exercise_calculations: exercise_calculation_responses }
  end
end

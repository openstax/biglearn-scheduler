class Services::FetchAlgorithmExerciseCalculations::Service < Services::ApplicationService
  def process(algorithm_exercise_calculations:)
    calculation_uuids = algorithm_exercise_calculations.map { |calc| calc[:calculation_uuid] }

    algorithm_exercise_calculations = AlgorithmExerciseCalculation
      .where(uuid: calculation_uuids)
      .to_a

    algorithm_exercise_calculation_responses = algorithm_exercise_calculations.map do |calculation|
      {
        calculation_uuid: calculation.uuid,
        ecosystem_matrix_uuid: calculation.ecosystem_matrix_uuid,
        algorithm_name: calculation.algorithm_name,
        exercise_uuids: calculation.exercise_uuids
      }
    end

    { algorithm_exercise_calculations: algorithm_exercise_calculation_responses }
  end
end

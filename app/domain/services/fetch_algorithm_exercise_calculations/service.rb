class Services::FetchAlgorithmExerciseCalculations::Service < Services::ApplicationService
  def process(algorithm_exercise_calculations:)
    return { algorithm_exercise_calculations: [] } if algorithm_exercise_calculations.empty?

    algorithm_exercise_calculation_values = algorithm_exercise_calculations.map do |calculation|
      [ calculation[:request_uuid], calculation[:student_uuid], calculation[:calculation_uuid] ]
    end

    algorithm_exercise_calculation_responses = AlgorithmExerciseCalculation
      .select(
        '"values"."request_uuid"',
        '"exercise_calculations"."student_uuid"',
        :uuid,
        :ecosystem_matrix_uuid,
        :algorithm_name,
        :exercise_uuids
      )
      .joins(:exercise_calculation)
      .joins(
        <<~JOIN_SQL
          INNER JOIN (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
            ("request_uuid", "student_uuid", "calculation_uuid")
            ON (
              "values"."student_uuid" IS NULL
                OR "exercise_calculations"."student_uuid" = "values"."student_uuid"::uuid
            ) AND (
              "values"."calculation_uuid" IS NULL
                OR "algorithm_exercise_calculations"."uuid" = "values"."calculation_uuid"::uuid
            )
        JOIN_SQL
      )
      .map do |algorithm_exercise_calculation|
      {
        request_uuid: algorithm_exercise_calculation.request_uuid,
        student_uuid: algorithm_exercise_calculation.student_uuid,
        calculation_uuid: algorithm_exercise_calculation.uuid,
        ecosystem_matrix_uuid: algorithm_exercise_calculation.ecosystem_matrix_uuid,
        algorithm_name: algorithm_exercise_calculation.algorithm_name,
        exercise_uuids: algorithm_exercise_calculation.exercise_uuids
      }
    end

    { algorithm_exercise_calculations: algorithm_exercise_calculation_responses }
  end
end

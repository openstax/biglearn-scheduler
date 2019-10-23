class Services::FetchAlgorithmExerciseCalculations::Service < Services::ApplicationService
  def process(algorithm_exercise_calculation_requests:)
    return { algorithm_exercise_calculations: [] } if algorithm_exercise_calculation_requests.empty?

    algorithm_exercise_calculation_values = algorithm_exercise_calculation_requests.map do |request|
      [ request[:request_uuid], request[:student_uuid], request[:calculation_uuids] ]
    end

    algorithm_exercise_calculation_responses = AlgorithmExerciseCalculation
      .select(
        '"values"."request_uuid"',
        '"exercise_calculations"."student_uuid"',
        :uuid,
        :ecosystem_matrix_uuid,
        :algorithm_name,
        :exercise_uuids,
        :updated_at
      )
      .joins(:exercise_calculation)
      .joins(
        <<~JOIN_SQL
          INNER JOIN (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
            ("request_uuid", "student_uuid", "calculation_uuids")
            ON (
              "values"."student_uuid" IS NULL
                OR "exercise_calculations"."student_uuid" = "values"."student_uuid"::uuid
            ) AND (
              (
                "values"."calculation_uuids" IS NULL
                  AND "exercise_calculations"."superseded_at" is NULL
              ) OR "algorithm_exercise_calculations"."uuid" = ANY(
                "values"."calculation_uuids"::uuid[]
              )
            )
        JOIN_SQL
      )
      .group_by(&:request_uuid)
      .map do |request_uuid, algorithm_exercise_calculations|
      {
        request_uuid: request_uuid,
        calculations: algorithm_exercise_calculations.map do |algorithm_exercise_calculation|
          {
            student_uuid: algorithm_exercise_calculation.student_uuid,
            calculation_uuid: algorithm_exercise_calculation.uuid,
            calculated_at: algorithm_exercise_calculation.updated_at.iso8601,
            ecosystem_matrix_uuid: algorithm_exercise_calculation.ecosystem_matrix_uuid,
            algorithm_name: algorithm_exercise_calculation.algorithm_name,
            exercise_uuids: algorithm_exercise_calculation.exercise_uuids
          }
        end
      }
    end

    { algorithm_exercise_calculations: algorithm_exercise_calculation_responses }
  end
end

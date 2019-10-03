class Services::FetchClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 100

  def process(algorithm_name:)
    sanitized_algorithm_name = ApplicationRecord.sanitize(algorithm_name.downcase)

    student_clue_calculations = StudentClueCalculation
      .where.not("\"algorithm_names\" @> ARRAY[#{sanitized_algorithm_name}]::varchar[]")
      .random_ordered
      .take(BATCH_SIZE)

    teacher_clue_calculations = TeacherClueCalculation
      .where.not("\"algorithm_names\" @> ARRAY[#{sanitized_algorithm_name}]::varchar[]")
      .random_ordered
      .take(BATCH_SIZE)

    clue_calculations = student_clue_calculations + teacher_clue_calculations
    clue_calculation_responses = clue_calculations.map do |clue_calculation|
      {
        calculation_uuid: clue_calculation.uuid,
        ecosystem_uuid: clue_calculation.ecosystem_uuid,
        student_uuids: clue_calculation.student_uuids,
        exercise_uuids: clue_calculation.exercise_uuids,
        responses: clue_calculation.responses
      }
    end

    { clue_calculations: clue_calculation_responses }
  end
end

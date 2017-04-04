class Services::FetchClueCalculations::Service
  def process(algorithm_name:)
    clue_calculations = ClueCalculation.where(algorithm_name: algorithm_name, is_calculated: false)
                                       .limit(1000)

    clue_calculation_responses = clue_calculations.map do |clue_calculation|
      {
        calculation_uuid: clue_calculation.uuid,
        exercise_uuids: clue_calculation.exercise_uuids,
        student_uuids: clue_calculation.student_uuids,
        ecosystem_uuid: clue_calculation.ecosystem_uuid
      }
    end

    { clue_calculations: clue_calculation_responses }
  end
end

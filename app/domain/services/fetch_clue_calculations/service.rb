class Services::FetchClueCalculations::Service
  def process(algorithm_name:)
    algorithm_clue_calculation_uuids =
      AlgorithmClueCalculation.where(algorithm_name: algorithm_name).pluck(:clue_calculation_uuid)
    clue_calculations = ClueCalculation.where.not(uuid: algorithm_clue_calculation_uuids)
                                       .limit(1000)

    clue_calculation_responses = clue_calculations.map do |clue_calculation|
      {
        calculation_uuid: clue_calculation.uuid,
        ecosystem_uuid: clue_calculation.ecosystem_uuid,
        exercise_uuids: clue_calculation.exercise_uuids,
        student_uuids: clue_calculation.student_uuids
      }
    end

    { clue_calculations: clue_calculation_responses }
  end
end

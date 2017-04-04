class Services::UpdateClueCalculations::Service
  def process(clue_calculation_updates:)
    algorithm_clue_calculations = clue_calculation_updates.map do |clue_calculation_update|
      AlgorithmClueCalculation.new(
        uuid: SecureRandom.uuid,
        clue_calculation_uuid: clue_calculation_update.fetch(:calculation_uuid),
        algorithm_name: clue_calculation_update.fetch(:algorithm_name),
        clue_data: clue_calculation_update.fetch(:clue_data)
      )
    end

    AlgorithmClueCalculation.import(
      algorithm_clue_calculations, validate: false, on_duplicate_key_update: {
        conflict_target: [ :clue_calculation_uuid, :algorithm_name ],
        columns: [ :clue_data ]
      }
    )
  end
end

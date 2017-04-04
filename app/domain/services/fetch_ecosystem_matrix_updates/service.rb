class Services::FetchEcosystemMatrixUpdates::Service
  def process(algorithm_name:)
    algorithm_ecosystem_matrix_update_uuids =
      AlgorithmEcosystemMatrixUpdate.where(algorithm_name: algorithm_name)
                                    .pluck(:ecosystem_matrix_update_uuid)
    ecosystem_matrix_updates =
      EcosystemMatrixUpdate.where.not(uuid: algorithm_ecosystem_matrix_update_uuids).limit(1000)

    ecosystem_matrix_update_responses = ecosystem_matrix_updates.map do |ecosystem_matrix_update|
      {
        calculation_uuid: ecosystem_matrix_update.uuid,
        ecosystem_uuid: ecosystem_matrix_update.ecosystem_uuid
      }
    end

    { ecosystem_matrix_updates: ecosystem_matrix_update_responses }
  end
end

class Services::FetchEcosystemMatrixUpdates::Service
  def process(algorithm_name:)
    ecosystem_matrix_updates = EcosystemMatrixUpdate.where(algorithm_name: algorithm_name,
                                                           is_updated: false)
                                                    .limit(1000)

    ecosystem_matrix_update_responses = ecosystem_matrix_updates.map do |ecosystem_matrix_update|
      {
        calculation_uuid: ecosystem_matrix_update.uuid,
        ecosystem_uuid: ecosystem_matrix_update.ecosystem_uuid
      }
    end

    { ecosystem_matrix_updates: ecosystem_matrix_update_responses }
  end
end

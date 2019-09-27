class Services::FetchEcosystemMatrixUpdates::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process(algorithm_name:)
    sanitized_algorithm_name = AlgorithmEcosystemMatrixUpdate.sanitize(algorithm_name.downcase)

    ecosystem_matrix_updates = EcosystemMatrixUpdate
      .where.not("\"algorithm_names\" @> ARRAY[#{sanitized_algorithm_name}]::varchar[]")
      .random_ordered
      .take(BATCH_SIZE)

    ecosystem_matrix_update_responses = ecosystem_matrix_updates.map do |ecosystem_matrix_update|
      {
        calculation_uuid: ecosystem_matrix_update.uuid,
        ecosystem_uuid: ecosystem_matrix_update.ecosystem_uuid
      }
    end

    { ecosystem_matrix_updates: ecosystem_matrix_update_responses }
  end
end

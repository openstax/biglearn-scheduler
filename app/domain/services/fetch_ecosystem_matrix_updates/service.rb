class Services::FetchEcosystemMatrixUpdates::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process(algorithm_name:)
    sanitized_algo_name = AlgorithmEcosystemMatrixUpdate.sanitize algorithm_name

    ecosystem_matrix_updates = EcosystemMatrixUpdate.transaction do
      # Extra memory is required to perform the hash anti-join efficiently
      EcosystemMatrixUpdate.connection.execute 'SET LOCAL work_mem=20480'

      EcosystemMatrixUpdate.where.not(
        AlgorithmEcosystemMatrixUpdate.where(
          <<-WHERE_SQL.strip_heredoc
            "algorithm_ecosystem_matrix_updates"."ecosystem_matrix_update_uuid" =
              "ecosystem_matrix_updates"."uuid"
              AND "algorithm_ecosystem_matrix_updates"."algorithm_name" = #{sanitized_algo_name}
          WHERE_SQL
        ).exists
      ).take(BATCH_SIZE)
    end

    ecosystem_matrix_update_responses = ecosystem_matrix_updates.map do |ecosystem_matrix_update|
      {
        calculation_uuid: ecosystem_matrix_update.uuid,
        ecosystem_uuid: ecosystem_matrix_update.ecosystem_uuid
      }
    end

    { ecosystem_matrix_updates: ecosystem_matrix_update_responses }
  end
end

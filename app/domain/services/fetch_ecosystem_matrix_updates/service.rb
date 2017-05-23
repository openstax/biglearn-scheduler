class Services::FetchEcosystemMatrixUpdates::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process(algorithm_name:)
    emu = EcosystemMatrixUpdate.arel_table
    aemu = AlgorithmEcosystemMatrixUpdate.arel_table
    emu_query = emu[:uuid].eq(aemu[:ecosystem_matrix_update_uuid]).and(
      aemu[:algorithm_name].eq(algorithm_name)
    )
    emu_join = "LEFT OUTER JOIN algorithm_ecosystem_matrix_updates ON #{emu_query.to_sql}"
    ecosystem_matrix_updates = EcosystemMatrixUpdate
                                 .joins(emu_join)
                                 .where(algorithm_ecosystem_matrix_updates: {id: nil})
                                 .limit(BATCH_SIZE)

    ecosystem_matrix_update_responses = ecosystem_matrix_updates.map do |ecosystem_matrix_update|
      {
        calculation_uuid: ecosystem_matrix_update.uuid,
        ecosystem_uuid: ecosystem_matrix_update.ecosystem_uuid
      }
    end

    { ecosystem_matrix_updates: ecosystem_matrix_update_responses }
  end
end

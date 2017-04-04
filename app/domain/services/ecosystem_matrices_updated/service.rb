class Services::EcosystemMatricesUpdated::Service
  def process(ecosystem_matrices_updated:)
    algorithm_ecosystem_matrix_updates =
      ecosystem_matrices_updated.map do |ecosystem_matrix_updated|
      AlgorithmEcosystemMatrixUpdate.new(
        uuid: SecureRandom.uuid,
        ecosystem_matrix_update_uuid: ecosystem_matrix_updated.fetch(:calculation_uuid),
        algorithm_name: ecosystem_matrix_updated.fetch(:algorithm_name)
      )
    end

    AlgorithmEcosystemMatrixUpdate.import(
      algorithm_ecosystem_matrix_updates, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :ecosystem_matrix_update_uuid, :algorithm_name ]
      }
    )
  end
end

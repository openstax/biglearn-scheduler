class Services::EcosystemMatricesUpdated::Service
  def process(ecosystem_matrices_updated:)
    relevant_update_uuids = ecosystem_matrices_updated.map { |update| update[:calculation_uuid] }
    ecosystem_matrix_update_uuids =
      EcosystemMatrixUpdate.where(uuid: relevant_update_uuids).pluck(:uuid)

    algorithm_ecosystem_matrix_updates = []
    ecosystem_matrix_updated_responses =
      ecosystem_matrices_updated.map do |ecosystem_matrix_updated|
      calculation_uuid = ecosystem_matrix_updated.fetch(:calculation_uuid)

      if ecosystem_matrix_update_uuids.include? calculation_uuid
        algorithm_ecosystem_matrix_updates << AlgorithmEcosystemMatrixUpdate.new(
          uuid: SecureRandom.uuid,
          ecosystem_matrix_update_uuid: calculation_uuid,
          algorithm_name: ecosystem_matrix_updated.fetch(:algorithm_name)
        )

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      else
        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
      end
    end

    AlgorithmEcosystemMatrixUpdate.import(
      algorithm_ecosystem_matrix_updates, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :ecosystem_matrix_update_uuid, :algorithm_name ]
      }
    )

    { ecosystem_matrix_updated_responses: ecosystem_matrix_updated_responses }
  end
end

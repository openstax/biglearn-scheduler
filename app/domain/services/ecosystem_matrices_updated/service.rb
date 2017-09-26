class Services::EcosystemMatricesUpdated::Service < Services::ApplicationService
  def process(ecosystem_matrices_updated:)
    relevant_update_uuids = ecosystem_matrices_updated.map { |update| update[:calculation_uuid] }
    ecosystem_matrix_updates_by_uuid = EcosystemMatrixUpdate.where(uuid: relevant_update_uuids)
                                                            .select(:uuid, :algorithm_names)
                                                            .index_by(&:uuid)

    algorithm_ecosystem_matrix_updates = []
    ecosystem_matrix_update_uuids_by_algorithm_names = Hash.new { |hash, key| hash[key] = [] }
    ecosystem_matrix_updated_responses =
      ecosystem_matrices_updated.map do |ecosystem_matrix_updated|
      calculation_uuid = ecosystem_matrix_updated.fetch(:calculation_uuid)

      ecosystem_matrix_update = ecosystem_matrix_updates_by_uuid[calculation_uuid]
      if ecosystem_matrix_update.present?
        algorithm_name = ecosystem_matrix_updated.fetch(:algorithm_name)

        algorithm_ecosystem_matrix_updates << AlgorithmEcosystemMatrixUpdate.new(
          uuid: SecureRandom.uuid,
          ecosystem_matrix_update: ecosystem_matrix_update,
          algorithm_name: algorithm_name
        )

        ecosystem_matrix_update_uuids_by_algorithm_names[algorithm_name] << calculation_uuid \
          unless ecosystem_matrix_update.algorithm_names.include?(algorithm_name)

        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_accepted' }
      else
        { calculation_uuid: calculation_uuid, calculation_status: 'calculation_unknown' }
      end
    end

    AlgorithmEcosystemMatrixUpdate.import(
      algorithm_ecosystem_matrix_updates, validate: false, on_duplicate_key_update: {
        conflict_target: [ :ecosystem_matrix_update_uuid, :algorithm_name ],
        columns: [ :uuid ]
      }
    )

    ecosystem_matrix_update_uuids_by_algorithm_names.each do |algorithm_name, uuids|
      sanitized_algorithm_name = EcosystemMatrixUpdate.sanitize(algorithm_name.downcase)

      EcosystemMatrixUpdate.where(uuid: uuids).update_all(
        "\"algorithm_names\" = \"algorithm_names\" || #{sanitized_algorithm_name}::varchar"
      )
    end

    { ecosystem_matrix_updated_responses: ecosystem_matrix_updated_responses }
  end
end

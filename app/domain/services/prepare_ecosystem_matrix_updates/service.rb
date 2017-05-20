class Services::PrepareEcosystemMatrixUpdates::Service < Services::ApplicationService
  UPDATE_THRESHOLD = 0.1
  RESPONSE_COUNT_QUERY = "new_response_count > #{UPDATE_THRESHOLD} * response_count"
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareEcosystemMatrixUpdates' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    # Do all the processing in batches to avoid OOM problems
    total_ecosystems = 0
    loop do
      num_ecosystems = Ecosystem.transaction do
        # Get Ecosystems with Exercises whose number of Responses that have not yet
        # been used in EcosystemMatrixUpdates exceeds the UPDATE_THRESHOLD
        # The subquery is needed because FOR UPDATE
        # cannot be used in the same query as GROUP BY or DISTINCT
        subquery = Exercise.select('"ecosystem_exercises"."ecosystem_uuid"')
                           .with_response_counts(select: '"exercises"."uuid"')
                           .joins(:ecosystem_exercises)
                           .where(RESPONSE_COUNT_QUERY)
                           .limit(BATCH_SIZE)
        ecosystem_uuids = Ecosystem.where(uuid: subquery).lock.pluck(:uuid)

        # Delete existing AlgorithmEcosystemMatrixUpdate for affected Ecosystems,
        # since they need to be recalculated
        ecosystem_matrix_update_uuids = EcosystemMatrixUpdate.where(ecosystem_uuid: ecosystem_uuids)
                                                             .pluck(:uuid)
        AlgorithmEcosystemMatrixUpdate
          .where(ecosystem_matrix_update_uuid: ecosystem_matrix_update_uuids)
          .delete_all

        ecosystem_matrix_updates = ecosystem_uuids.map do |ecosystem_uuid|
          EcosystemMatrixUpdate.new(
            uuid: SecureRandom.uuid,
            ecosystem_uuid: ecosystem_uuid
          )
        end

        # Record any new ecosystem matrix updates
        EcosystemMatrixUpdate.import(
          ecosystem_matrix_updates, validate: false, on_duplicate_key_update: {
            conflict_target: [ :ecosystem_uuid ],
            columns: [ :uuid ]
          }
        )

        # Record the fact that the EcosystemMatrixUpdates are up-to-date with the latest Responses
        Response.where(ecosystem_uuid: ecosystem_uuids)
                .update_all(used_in_ecosystem_matrix_updates: true)

        ecosystem_uuids.size
      end

      # If we got less ecosystems than the batch size, then this is the last batch
      total_ecosystems += num_ecosystems
      break if num_ecosystems < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareEcosystemMatrixUpdates' do |logger|
      logger.debug do
        "#{total_ecosystems} ecosystem(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end
end

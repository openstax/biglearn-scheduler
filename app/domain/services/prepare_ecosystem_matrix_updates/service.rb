class Services::PrepareEcosystemMatrixUpdates::Service < Services::ApplicationService
  UPDATE_THRESHOLD = 0.1
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
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
        subquery = Exercise
          .with_new_response_ratio_above_threshold(threshold: UPDATE_THRESHOLD, limit: BATCH_SIZE)
          .joins(:ecosystem_exercises)
          .select('"ecosystem_exercises"."ecosystem_uuid"')
        ecosystem_uuids = Ecosystem.where(uuid: subquery)
                                   .lock('FOR UPDATE SKIP LOCKED')
                                   .pluck(:uuid)

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

        # Cleanup AlgorithmEcosystemMatrixUpdates that no longer have
        # an associated EcosystemMatrixUpdate record
        AlgorithmEcosystemMatrixUpdate.unassociated.delete_all

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
        "#{total_ecosystems} ecosystem(s) processed in #{Time.current - start_time} second(s)"
      end
    end
  end
end

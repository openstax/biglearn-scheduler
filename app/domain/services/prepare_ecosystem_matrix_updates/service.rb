class Services::PrepareEcosystemMatrixUpdates::Service < Services::ApplicationService
  RESPONSE_BATCH_SIZE = 1000
  # Update once the number of new responses is 10% of the total for any exercise in the ecosystem
  UPDATE_THRESHOLD = 0.1
  ECOSYSTEM_BATCH_SIZE = 1

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    # Do all the processing in batches to avoid OOM problems
    total_responses = 0
    loop do
      num_responses = Response.transaction do
        responses = Response.select(:uuid, '"exercise_groups"."uuid" AS "group_uuid"')
                            .joins(exercise: :exercise_group)
                            .where(used_in_response_count: false)
                            .lock('FOR NO KEY UPDATE OF "responses", "exercise_groups" SKIP LOCKED')
                            .take(RESPONSE_BATCH_SIZE)

        group_uuids = responses.map(&:group_uuid)
        ExerciseGroup.where(uuid: group_uuids).update_all(
          <<-UPDATE_SQL.strip_heredoc
            "response_count" = (
              SELECT COUNT(DISTINCT "responses"."trial_uuid")
                FROM "exercises"
                  INNER JOIN "responses"
                    ON "responses"."exercise_uuid" = "exercises"."uuid"
                WHERE "exercises"."group_uuid" = "exercise_groups"."uuid"
            )
          UPDATE_SQL
        )

        response_uuids = responses.map(&:uuid)
        Response.where(uuid: response_uuids).update_all(used_in_response_count: true)

        responses.size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < RESPONSE_BATCH_SIZE
    end

    ee = EcosystemExercise.arel_table
    eg = ExerciseGroup.arel_table

    # Get Ecosystems with Exercises whose number of Responses that have not yet
    # been used in EcosystemMatrixUpdates exceeds the UPDATE_THRESHOLD
    total_ecosystems = 0
    loop do
      num_ecosystem_uuids = Ecosystem.transaction do
        ecosystem_uuids = Ecosystem
          .joins(ecosystem_exercises: { exercise: :exercise_group })
          .where(
            ee[:next_ecosystem_matrix_update_response_count].eq(nil).or(
              eg[:response_count].gteq(ee[:next_ecosystem_matrix_update_response_count])
            )
          )
          .limit(ECOSYSTEM_BATCH_SIZE)
          .lock('FOR NO KEY UPDATE OF "ecosystems" SKIP LOCKED')
          .pluck(:uuid)
        next 0 if ecosystem_uuids.empty?

        uniq_ecosystem_uuids = ecosystem_uuids.uniq
        total_ecosystems += uniq_ecosystem_uuids.size

        EcosystemExercise
          .where(ecosystem_uuid: uniq_ecosystem_uuids)
          .where('"exercises"."uuid" = "ecosystem_exercises"."exercise_uuid"')
          .update_all(
            <<-UPDATE_SQL.strip_heredoc
              "next_ecosystem_matrix_update_response_count" =
                FLOOR((1 + #{UPDATE_THRESHOLD}) * "exercise_groups"."response_count") + 1
                FROM "exercises"
                  INNER JOIN "exercise_groups"
                    ON "exercise_groups"."uuid" = "exercises"."group_uuid"
            UPDATE_SQL
          )

        ecosystem_matrix_updates = uniq_ecosystem_uuids.map do |ecosystem_uuid|
          EcosystemMatrixUpdate.new(
            uuid: SecureRandom.uuid,
            ecosystem_uuid: ecosystem_uuid
          )
        end

        # Record any new ecosystem matrix updates
        EcosystemMatrixUpdate.import(
          ecosystem_matrix_updates, validate: false, on_duplicate_key_update: {
            conflict_target: [ :ecosystem_uuid ], columns: [ :uuid ]
          }
        )

        # Cleanup AlgorithmEcosystemMatrixUpdates that no longer have
        # an associated EcosystemMatrixUpdate record
        AlgorithmEcosystemMatrixUpdate.unassociated.delete_all

        ecosystem_uuids.size
      end

      # If we got less ecosystem_uuids than the batch size, then this is the last batch
      break if num_ecosystem_uuids < ECOSYSTEM_BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s) and #{total_ecosystems
      } ecosystem(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end

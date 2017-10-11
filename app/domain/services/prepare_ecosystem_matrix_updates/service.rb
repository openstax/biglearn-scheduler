class Services::PrepareEcosystemMatrixUpdates::Service < Services::ApplicationService
  NEW_ECOSYSTEM_BATCH_SIZE = 10
  RESPONSE_BATCH_SIZE = 100

  # Update once every time we have 10% new responses for any exercise in the ecosystem
  UPDATE_THRESHOLD = 0.1

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ee = EcosystemExercise.arel_table
    eg = ExerciseGroup.arel_table

    total_new_ecosystems = 0
    total_responses = 0
    loop do
      num_new_ecosystems, num_responses = Response.transaction do
        # Get new Ecosystems that haven't yet had any EcosystemMatrixUpdates and lock them
        new_ecosystem_uuids = Ecosystem
          .joins(:ecosystem_exercises)
          .where(ee[:next_ecosystem_matrix_update_response_count].eq(nil))
          .lock('FOR NO KEY UPDATE OF "ecosystems" SKIP LOCKED')
          .limit(NEW_ECOSYSTEM_BATCH_SIZE)
          .pluck(:uuid)

        # Find responses not yet used in the response counts
        # The join to ecosystems is only present here to lock the ecosystems preemptively
        responses = Response
          .select(:uuid, '"exercise_groups"."uuid" AS "group_uuid"')
          .joins(exercise: { exercise_group: { exercises: { ecosystem_exercises: :ecosystem } } })
          .where(used_in_response_count: false)
          .lock('FOR NO KEY UPDATE OF "responses", "exercise_groups", "ecosystems" SKIP LOCKED')
          .take(RESPONSE_BATCH_SIZE)
        num_responses = responses.size

        updated_ecosystem_uuids = if num_responses > 0
          # Update the global counts of responses per exercise group
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

          # Mark the responses as used in response counts
          response_uuids = responses.map(&:uuid)
          Response.where(uuid: response_uuids).update_all(used_in_response_count: true)

          # Get Ecosystems with Exercises whose number of Responses that have not yet
          # been used in EcosystemMatrixUpdates exceeds the UPDATE_THRESHOLD
          # We already locked them earlier, so we don't need to lock them here again
          Ecosystem
            .joins(ecosystem_exercises: { exercise: :exercise_group })
            .where(
              eg[:uuid].in(group_uuids).and(
                eg[:response_count].gteq(ee[:next_ecosystem_matrix_update_response_count])
              )
            )
            .pluck(:uuid)
        else
          []
        end

        uniq_ecosystem_uuids = (new_ecosystem_uuids + updated_ecosystem_uuids).uniq

        next [ 0, num_responses ] if uniq_ecosystem_uuids.empty?

        num_new_ecosystems = new_ecosystem_uuids.size

        # Record the counts needed to trigger the next update
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
            conflict_target: [ :ecosystem_uuid ], columns: [ :uuid, :algorithm_names ]
          }
        )

        # Cleanup AlgorithmEcosystemMatrixUpdates that no longer have
        # an associated EcosystemMatrixUpdate record
        AlgorithmEcosystemMatrixUpdate.unassociated.delete_all

        [ num_new_ecosystems, num_responses ]
      end

      total_new_ecosystems += num_new_ecosystems
      total_responses += num_responses
      # If we got less new ecosystems and responses than the batch size, then this is the last batch
      break if num_new_ecosystems < NEW_ECOSYSTEM_BATCH_SIZE && num_responses < RESPONSE_BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s) and #{total_new_ecosystems
      } new ecosystem(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end

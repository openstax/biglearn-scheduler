class Services::PrepareEcosystemMatrixUpdates::Service < Services::ApplicationService
  RESPONSE_BATCH_SIZE = 100
  EXERCISE_GROUP_BATCH_SIZE = 10

  # Update once every time we have 10% new responses for any exercise in the ecosystem
  UPDATE_THRESHOLD = 0.1

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ee = Ecosystem.arel_table
    eex = EcosystemExercise.arel_table
    eg = ExerciseGroup.arel_table

    # Check new responses and update the response count for each affected exercise group
    total_responses = 0
    loop do
      num_responses = Response.transaction do
        # Find responses not yet used in the response counts
        responses = Response
          .select(:uuid, '"exercise_groups"."uuid" AS "group_uuid"')
          .joins(exercise: :exercise_group)
          .where(used_in_response_count: false)
          .lock('FOR NO KEY UPDATE OF "responses", "exercise_groups" SKIP LOCKED')
          .take(RESPONSE_BATCH_SIZE)
        num_responses = responses.size
        next 0 if num_responses == 0

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
            ),
            "used_in_ecosystem_matrix_updates" = FALSE
          UPDATE_SQL
        )

        # Mark the responses as used in response counts
        response_uuids = responses.map(&:uuid)
        Response.where(uuid: response_uuids).update_all(used_in_response_count: true)

        num_responses
      end

      total_responses += num_responses
      # If we got less responses than the batch size, then this is the last batch
      break if num_responses < RESPONSE_BATCH_SIZE
    end

    # Check updated exercise groups and their ecosystems to see if we triggered a new matrix update
    total_ecosystems = 0
    loop do
      num_exercise_groups, num_ecosystems = ExerciseGroup.transaction do
        group_uuids = ExerciseGroup.where(used_in_ecosystem_matrix_updates: false)
                                   .lock('FOR NO KEY UPDATE SKIP LOCKED')
                                   .limit(EXERCISE_GROUP_BATCH_SIZE)
                                   .pluck(:uuid)
        num_exercise_groups = group_uuids.size
        next [ 0, 0 ] if num_exercise_groups == 0

        # Get Ecosystems with Exercises whose number of Responses that have not yet
        # been used in EcosystemMatrixUpdates exceeds the UPDATE_THRESHOLD
        # We order by id here to avoid deadlocks when locking the ecosystems
        # Cannot use SKIP LOCKED here, otherwise we could miss an Ecosystem that needs to be updated
        ecosystem_uuids = Ecosystem
          .where(
            EcosystemExercise.joins(exercise: :exercise_group).where(
              eex[:ecosystem_uuid].eq(ee[:uuid])
                .and(eg[:uuid].in(group_uuids))
                .and(eg[:response_count].gteq(eex[:next_ecosystem_matrix_update_response_count]))
            ).exists
          )
          .order(:id)
          .lock('FOR NO KEY UPDATE')
          .pluck(:uuid)

        ExerciseGroup.where(uuid: group_uuids).update_all(used_in_ecosystem_matrix_updates: true)

        num_ecosystems = ecosystem_uuids.size
        next [ num_exercise_groups, 0 ] if num_ecosystems == 0

        # Record the counts needed to trigger the next update
        EcosystemExercise
          .where(ecosystem_uuid: ecosystem_uuids)
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

        ecosystem_matrix_updates = ecosystem_uuids.map do |ecosystem_uuid|
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

        [ num_exercise_groups, num_ecosystems ]
      end

      total_ecosystems += num_ecosystems
      # If we got less exercise groups than the batch size, then this is the last batch
      break if num_exercise_groups < EXERCISE_GROUP_BATCH_SIZE
    end

    log(:debug) do
      "#{total_responses} response(s) and #{total_ecosystems
      } ecosystem(s) processed in #{Time.current - start_time} second(s)"
    end
  end
end

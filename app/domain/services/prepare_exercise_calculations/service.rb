class Services::PrepareExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareExerciseCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    # Do all the processing in batches to avoid OOM problems
    total_responses = 0
    loop do
      num_responses = Response.transaction do
        # Get Responses that have not yet been used in ExerciseCalculations
        # and extract their student_uuids
        responses = Response.where(used_in_exercise_calculations: false)
                            .lock
                            .limit(BATCH_SIZE)
                            .select(:uuid, :student_uuid)
        response_uuids = responses.map(&:uuid)
        student_uuids = responses.map(&:student_uuid).uniq

        # Find all assignments for the students above that need SPEs or PEs
        # Extract unique (student_uuid, ecosystem_uuid) pairs from them
        ecosystem_uuid_student_uuid_pairs = Assignment.need_spes_or_pes
                                                      .where(student_uuid: student_uuids)
                                                      .distinct
                                                      .pluck(:ecosystem_uuid, :student_uuid)

        # Create the ExerciseCalculations
        exercise_calculations = ecosystem_uuid_student_uuid_pairs
                                  .map do |ecosystem_uuid, student_uuid|
          ExerciseCalculation.new(
            uuid: SecureRandom.uuid,
            ecosystem_uuid: ecosystem_uuid,
            student_uuid: student_uuid
          )
        end

        # Record the ExerciseCalculations
        ExerciseCalculation.import(
          exercise_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :student_uuid, :ecosystem_uuid ], columns: [ :uuid ]
          }
        )

        # Cleanup AlgorithmExerciseCalculations that no longer have
        # an associated ExerciseCalculation record
        AlgorithmExerciseCalculation.unassociated.delete_all

        # Record the fact that the CLUes are up-to-date with the latest Responses
        Response.where(uuid: response_uuids).update_all(used_in_exercise_calculations: true)

        responses.size
      end

      # If we got less responses than the batch size, then this is the last batch
      total_responses += num_responses
      break if num_responses < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareExerciseCalculations' do |logger|
      logger.debug do
        "#{total_responses} response(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end
end

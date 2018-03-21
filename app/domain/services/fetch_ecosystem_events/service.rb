class Services::FetchEcosystemEvents::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  RELEVANT_EVENT_TYPES = [ :create_ecosystem ]

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ec = Ecosystem.arel_table
    last_id = nil
    ecosystem_ids_to_requery = []
    results = []
    total_events = 0
    total_ecosystems = 0

    # Query events for all ecosystems in chunks
    loop do
      num_ecosystems = Ecosystem.transaction do
        # Since create_ecosystem is our only event here right now,
        # we can ignore all ecosystems that already processed it (sequence_number > 0)
        ecosystem_relation = Ecosystem.where(sequence_number: 0)
                                      .order(:uuid)
                                      .lock('FOR NO KEY UPDATE SKIP LOCKED')
        ecosystem_relation = ecosystem_relation.where(ec[:id].gt(last_id)) unless last_id.nil?
        ecosystems = ecosystem_relation.take(BATCH_SIZE)
        next 0 if ecosystems.empty?

        last_id = ecosystems.last.id

        partial_ecosystem_ids_to_requery, partial_results, num_events =
          fetch_and_process_ecosystem_events(ecosystems)

        ecosystem_ids_to_requery.concat partial_ecosystem_ids_to_requery
        results.concat partial_results
        total_events += num_events

        ecosystems.size
      end

      total_ecosystems += num_ecosystems
      break if num_ecosystems < BATCH_SIZE
    end

    # Re-query events for ecosystems that still
    # had more events available until they are all exhausted
    # This is done so we can catch up with ecosystems emitting a lot of events
    loop do
      Ecosystem.transaction do
        ecosystems = Ecosystem.where(id: ecosystem_ids_to_requery.shift(BATCH_SIZE))
                              .lock('FOR NO KEY UPDATE SKIP LOCKED')
                              .to_a
        next if ecosystems.empty?

        partial_ecosystem_ids_to_requery, partial_results, num_events =
          fetch_and_process_ecosystem_events(ecosystems)

        ecosystem_ids_to_requery.concat partial_ecosystem_ids_to_requery
        results.concat partial_results
        total_events += num_events
      end

      break if ecosystem_ids_to_requery.empty?
    end

    log(:debug) do
      conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
      time = Time.current - start_time

      "Received: #{total_events} event(s) from #{total_ecosystems} ecosystem(s)" +
      " with #{conflicts} conflict(s) in #{time} second(s)"
    end
  end

  protected

  def fetch_and_process_ecosystem_events(ecosystems)
    ecosystem_ids_to_requery = []
    results = []
    total_events = 0

    ecosystem_event_requests = []
    ecosystems_by_ecosystem_uuid = ecosystems.map do |ecosystem|
      ecosystem_event_requests << { ecosystem: ecosystem, event_types: RELEVANT_EVENT_TYPES }

      [ ecosystem.uuid, ecosystem ]
    end.to_h

    ecosystem_event_responses = OpenStax::Biglearn::Api
      .fetch_ecosystem_events(ecosystem_event_requests)
      .values
      .map(&:deep_symbolize_keys)

    exercise_pools = []
    exercise_groups = []
    exercises = []
    ecosystem_exercises = []
    ecosystems = ecosystem_event_responses.map do |ecosystem_event_response|
      events = ecosystem_event_response.fetch :events
      num_events = events.size
      next if num_events == 0

      total_events += num_events

      ecosystem_uuid = ecosystem_event_response.fetch :ecosystem_uuid
      ecosystem = ecosystems_by_ecosystem_uuid.fetch ecosystem_uuid

      ecosystem_ids_to_requery << ecosystem.id \
        unless ecosystem_event_response.fetch(:is_gap) ||
               ecosystem_event_response.fetch(:is_end)

      events_by_type = events.group_by { |event| event.fetch(:event_type) }

      # create_ecosystem event determines the ecosystem contents,
      # including exercise pools and exercises
      create_ecosystems = events_by_type['create_ecosystem'] || []
      last_create_ecosystem = create_ecosystems.last
      if last_create_ecosystem.present?
        data = last_create_ecosystem.fetch(:event_data)

        book_container_uuids_by_exercise_uuids = Hash.new { |hash, key| hash[key] = [] }
        data.fetch(:book).fetch(:contents).each do |content|
          container_uuid = content.fetch(:container_uuid)

          content.fetch(:pools).each do |pool|
            pool_uuid = SecureRandom.uuid
            assignment_types = pool.fetch(:use_for_personalized_for_assignment_types)
            exercise_uuids = pool.fetch(:exercise_uuids, [])

            exercise_pools << ExercisePool.new(
              uuid: pool_uuid,
              ecosystem_uuid: ecosystem_uuid,
              book_container_uuid: container_uuid,
              use_for_clue: pool.fetch(:use_for_clue),
              use_for_personalized_for_assignment_types: assignment_types,
              exercise_uuids: exercise_uuids
            )

            exercise_uuids.each do |exercise_uuid|
              book_container_uuids_by_exercise_uuids[exercise_uuid] << container_uuid
            end
          end
        end

        exercise_hashes = data.fetch(:exercises).uniq { |ex_hash| ex_hash.fetch(:exercise_uuid) }

        exercise_hashes.map { |ex_hash| ex_hash.fetch(:group_uuid) }.uniq.map do |group_uuid|
          exercise_groups << ExerciseGroup.new(
            uuid: group_uuid,
            response_count: 0,
            next_update_response_count: 1,
            trigger_ecosystem_matrix_update: true
          )
        end

        ecosystem.exercise_uuids = exercise_hashes.map do |ex_hash|
          ex_hash.fetch(:exercise_uuid).tap do |exercise_uuid|
            exercises << Exercise.new(
              uuid: exercise_uuid,
              group_uuid: ex_hash.fetch(:group_uuid),
              version: ex_hash.fetch(:version)
            )

            book_container_uuids = book_container_uuids_by_exercise_uuids[exercise_uuid].uniq
            ecosystem_exercises << EcosystemExercise.new(
              uuid: SecureRandom.uuid,
              ecosystem_uuid: ecosystem_uuid,
              exercise_uuid: exercise_uuid,
              book_container_uuids: book_container_uuids
            )
          end
        end
      end

      ecosystem.sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max + 1

      ecosystem
    end.compact

    results << ExerciseGroup.import(
      exercise_groups, validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ], columns: [ :trigger_ecosystem_matrix_update ]
      }
    )

    results << Exercise.import(
      exercises, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    )

    results << EcosystemExercise.import(
      ecosystem_exercises, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    )

    results << ExercisePool.import(
      exercise_pools, validate: false, on_duplicate_key_ignore: {
        conflict_target: [ :uuid ]
      }
    )

    results << Ecosystem.import(
      ecosystems, validate: false, on_duplicate_key_update: {
        conflict_target: [ :uuid ], columns: [ :sequence_number, :exercise_uuids ]
      }
    )

    [ ecosystem_ids_to_requery, results, total_events ]
  end
end

class Services::FetchEcosystemEvents::Service
  ECOSYSTEM_BATCH_SIZE = 1

  RELEVANT_EVENT_TYPES = [ :create_ecosystem ]

  def process
    start_time = Time.now
    Rails.logger.tagged 'FetchEcosystemEvents' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    # Since create_ecosystem is our only event here right now,
    # we can ignore all ecosystems that already processed it (sequence_number > 0)
    ecosystem_ids = Ecosystem.where(sequence_number: 0).ids
    total_ecosystems = ecosystem_ids.size

    results = []
    total_events = 0
    ecosystem_ids.each_slice(ECOSYSTEM_BATCH_SIZE) do |ecosystem_ids|
      Ecosystem.transaction do
        ecosystem_event_requests = []
        ecosystems_by_ecosystem_uuid = Ecosystem.where(id: ecosystem_ids).map do |ecosystem|
          ecosystem_event_requests << { ecosystem: ecosystem, event_types: RELEVANT_EVENT_TYPES }

          [ ecosystem.uuid, ecosystem ]
        end.to_h

        ecosystem_event_responses = \
          OpenStax::Biglearn::Api.fetch_ecosystem_events(ecosystem_event_requests)
                                 .values
                                 .map(&:deep_symbolize_keys)

        exercise_pools = []
        ecosystem_exercises = []
        exercises = []
        ecosystems = ecosystem_event_responses.map do |ecosystem_event_response|
          events = ecosystem_event_response.fetch :events
          num_events = events.size
          next if num_events == 0

          total_events += num_events

          ecosystem_uuid = ecosystem_event_response.fetch :ecosystem_uuid
          ecosystem = ecosystems_by_ecosystem_uuid.fetch ecosystem_uuid

          events_by_type = events.group_by{ |event| event.fetch(:event_type) }

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

            data.fetch(:exercises).each do |exercise|
              exercise_uuid = exercise.fetch(:exercise_uuid)
              exercise_group_uuid = exercise.fetch(:group_uuid)
              book_container_uuids = book_container_uuids_by_exercise_uuids[exercise_uuid]

              ecosystem_exercises << EcosystemExercise.new(
                uuid: SecureRandom.uuid,
                ecosystem_uuid: ecosystem_uuid,
                exercise_group_uuid: exercise_group_uuid,
                book_container_uuids: book_container_uuids
              )

              exercises << Exercise.new(
                uuid: exercise_uuid,
                group_uuid: exercise_group_uuid,
                version: exercise.fetch(:version)
              )
            end
          end

          ecosystem.sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max + 1

          ecosystem
        end.compact

        results << ExercisePool.import(
          exercise_pools, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ],
            columns: [
              :ecosystem_uuid,
              :book_container_uuid,
              :use_for_clue,
              :use_for_personalized_for_assignment_types
            ]
          }
        )

        results << EcosystemExercise.import(
          ecosystem_exercises, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ],
            columns: [ :ecosystem_uuid, :exercise_group_uuid, :book_container_uuids ]
          }
        )

        results << Exercise.import(
          exercises, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
        )

        # This is done last because the sequence_number update marks events as processed
        results << Ecosystem.import(
          ecosystems, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ], columns: [ :sequence_number ]
          }
        )
      end
    end

    Rails.logger.tagged 'FetchEcosystemEvents' do |logger|
      logger.debug do
        conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
        time = Time.now - start_time

        "Received #{total_events} event(s) from #{total_ecosystems} ecosystems(s)" +
        " with #{conflicts} conflict(s) in #{time} second(s)"
      end
    end
  end
end

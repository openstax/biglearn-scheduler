RELEVANT_ECOSYSTEM_EVENT_TYPES = [ :create_ecosystem ]

namespace :fetch_events do
  task ecosystems: :environment do
    start_time = Time.now
    Rails.logger.tagged 'fetch_events:ecosystems' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    Ecosystem.transaction do
      # Since create_ecosystem is our only event here right now,
      # we can ignore all ecosystems that already processed it
      ecosystem_event_requests = Ecosystem.where(sequence_number: 0).map do |ecosystem|
        { ecosystem: ecosystem, event_types: RELEVANT_ECOSYSTEM_EVENT_TYPES }
      end
      ecosystem_event_responses = \
        OpenStax::Biglearn::Api.fetch_ecosystem_events(ecosystem_event_requests)
                               .values
                               .map(&:deep_symbolize_keys)

      exercise_pools = []
      exercises = []
      ecosystems = ecosystem_event_responses.map do |ecosystem_event_response|
        events = ecosystem_event_response.fetch(:events)
        next if events.empty?

        ecosystem_uuid = ecosystem_event_response.fetch(:ecosystem_uuid)
        events = ecosystem_event_response.fetch(:events)
        sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max + 1
        events_by_type = events.group_by{ |event| event.fetch(:event_type) }

        Ecosystem.new(uuid: ecosystem_uuid, sequence_number: sequence_number).tap do |ecosystem|

          # create_ecosystem event determines the ecosystem contents,
          # including exercise pools and exercises
          create_ecosystems = events_by_type['create_ecosystem'] || []
          last_create_ecosystem = create_ecosystems.last
          if last_create_ecosystem.present?
            data = last_create_ecosystem.fetch(:event_data)

            data.fetch(:exercises).each do |exercise|
              exercises << Exercise.new(
                uuid: SecureRandom.uuid,
                exercise_uuid: exercise.fetch(:exercise_uuid),
                group_uuid: exercise.fetch(:group_uuid),
                version: exercise.fetch(:version)
              )
            end

            data.fetch(:book).fetch(:contents).each do |content|
              container_uuid = content.fetch(:container_uuid)
              assignment_types = pool.fetch(:use_for_personalized_for_assignment_types)

              content.fetch(:pools).each do |pool|
                exercise_pools << ExercisePool.new(
                  uuid: SecureRandom.uuid,
                  ecosystem_uuid: ecosystem_uuid,
                  book_container_uuid: container_uuid,
                  use_for_clue: pool.fetch(:use_for_clue),
                  use_for_personalized_for_assignment_types: assignment_types,
                  exercise_uuids: pool.fetch(:exercise_uuids)
                )
              end
            end
          end

        end
      end.compact

      results = []

      results << Ecosystem.import(
        ecosystems, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ], columns: [ :sequence_number ]
        }
      )

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

      results << Exercise.import(
        exercises, validate: false, on_duplicate_key_update: {
          conflict_target: [ :uuid ],
          columns: [ :exercise_uuid, :group_uuid, :version, :exercise_pool_uuids ]
        }
      )

      Rails.logger.tagged 'fetch_events:ecosystems' do |logger|
        logger.info do
          ecosystem_events = ecosystem_event_responses.map do |response|
            response.fetch(:events).size
          end.reduce(0, :+)
          failures = results.map { |result| result.failed_instances.size }.reduce(0, :+)
          num_inserts = results.map(&:num_inserts).reduce(0, :+)

          "Received: #{ecosystem_events} events in #{ecosystems.size} ecosystems" +
          " - Successful: #{num_inserts} insert(s) - Failed: #{failures} insert(s)" +
          " - Took: #{Time.now - start_time} second(s)"
        end
      end
    end
  end
end

class Services::FetchEcosystemMetadatas::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    total_ecosystems = 0

    loop do
      num_ecosystems = Ecosystem.transaction do
        ecosystem_responses = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas(
          max_num_metadatas: BATCH_SIZE
        ).fetch(:ecosystem_responses)

        ecosystems_size = ecosystem_responses.size
        next 0 if ecosystems_size == 0

        ecosystems = ecosystem_responses.map do |ecosystem_hash|
          Ecosystem.new uuid: ecosystem_hash.fetch(:uuid),
                        sequence_number: 0,
                        metadata_sequence_number: ecosystem_hash.fetch(:metadata_sequence_number),
                        exercise_uuids: []
        end

        # No sort needed because of on_duplicate_key_ignore
        Ecosystem.import ecosystems, validate: false,
                                     on_duplicate_key_ignore: { conflict_target: [ :uuid ] }

        ecosystems_size
      end

      total_ecosystems += num_ecosystems
      break if num_ecosystems < BATCH_SIZE
    end

    log(:debug) { "Received: #{total_ecosystems} - Took: #{Time.current - start_time} second(s)" }
  end
end

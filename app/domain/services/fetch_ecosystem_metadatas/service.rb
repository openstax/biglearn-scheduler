class Services::FetchEcosystemMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ecosystem_responses = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                                 .fetch(:ecosystem_responses)

    unless ecosystem_responses.empty?
      ecosystems = ecosystem_responses.map do |ecosystem_hash|
        Ecosystem.new uuid: ecosystem_hash.fetch(:uuid),
                      sequence_number: 0,
                      metadata_sequence_number: ecosystem_hash.fetch(:metadata_sequence_number),
                      exercise_uuids: []
      end

      # No sort needed because of on_duplicate_key_ignore
      Ecosystem.import ecosystems, validate: false,
                                   on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    end

    log(:debug) do
      "Received: #{ecosystem_responses.size} - Took: #{Time.current - start_time} second(s)"
    end
  end
end

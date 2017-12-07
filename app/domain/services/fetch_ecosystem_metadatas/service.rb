class Services::FetchEcosystemMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    ecosystem_responses = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                                 .fetch(:ecosystem_responses)
    ecosystem_uuids = ecosystem_responses.map { |ecosystem_hash| ecosystem_hash.fetch(:uuid) }

    Ecosystem.transaction do
      existing_ecosystem_uuids = Ecosystem.where(uuid: ecosystem_uuids).pluck(:uuid)

      ecosystems = ( ecosystem_uuids - existing_ecosystem_uuids ).map do |ecosystem_uuid|
        Ecosystem.new uuid: ecosystem_uuid, sequence_number: 0, exercise_uuids: []
      end

      result = Ecosystem.import ecosystems, validate: false,
                                            on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
      log(:debug) do
        response_count = ecosystem_responses.size
        existing_count = existing_ecosystem_uuids.size
        new_count = response_count - existing_count
        time = Time.current - start_time

        "Received: #{response_count} - Existing: #{existing_count}" +
        " - New: #{new_count} - Took: #{time} second(s)"
      end
    end
  end
end

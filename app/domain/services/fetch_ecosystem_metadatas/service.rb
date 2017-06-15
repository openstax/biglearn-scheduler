class Services::FetchEcosystemMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.current
    Rails.logger.tagged 'FetchEcosystemMetadatas' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    ecosystems = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                        .fetch(:ecosystem_responses)
                                        .map do |ecosystem_hash|
      Ecosystem.new uuid: ecosystem_hash.fetch(:uuid), sequence_number: 0, exercise_uuids: []
    end

    result = Ecosystem.import ecosystems, validate: false,
                                          on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    Rails.logger.tagged 'FetchEcosystemMetadatas' do |logger|
      logger.debug do
        metadatas = ecosystems.size
        conflicts = result.failed_instances.size
        successes = metadatas - conflicts
        total = Ecosystem.count
        time = Time.current - start_time

        "Received: #{metadatas} - Existing: #{conflicts} - New: #{successes}" +
        " - Total: #{total} - Took: #{time} second(s)"
      end
    end
  end
end

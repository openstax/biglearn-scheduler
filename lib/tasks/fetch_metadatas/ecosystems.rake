namespace :fetch_metadatas do
  task ecosystems: :environment do
    start_time = Time.now
    Rails.logger.tagged 'fetch_metadatas:ecosystems' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    ecosystems = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                        .fetch(:ecosystem_responses)
                                        .map do |ecosystem_hash|
      Ecosystem.new uuid: ecosystem_hash.fetch(:uuid), sequence_number: 0
    end

    result = Ecosystem.import ecosystems, validate: false,
                                          on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    Rails.logger.tagged 'fetch_metadatas:ecosystems' do |logger|
      logger.info do
        "Received: #{ecosystems.size} - Failed: #{result.failed_instances.size}" +
        " - New: #{result.num_inserts} - Total: #{Ecosystem.count}" +
        " - Took: #{Time.now - start_time} second(s)"
      end
    end
  end
end

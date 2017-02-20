namespace :fetch_metadatas do
  task ecosystems: :environment do
    Rails.logger.info do
      @start_time = Time.now

      "Fetch ecosystem metadatas started at #{@start_time}"
    end

    ecosystems = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                        .fetch(:ecosystem_responses)
                                        .map do |ecosystem|
      Ecosystem.new uuid: ecosystem.fetch(:uuid)
    end

    result = Ecosystem.import ecosystems, validate: false,
                                          on_duplicate_key_ignore: { conflict_target: [ :uuid ] }

    Rails.logger.info do
      "Ecosystems: Received: #{ecosystems.size} - Failed: #{result.failed_instances.size}" +
      " - New: #{result.num_inserts} - Total: #{Ecosystem.count}" +
      " - Took: #{Time.now - @start_time} second(s)"
    end
  end
end

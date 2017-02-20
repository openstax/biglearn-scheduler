namespace :ecosystem do
  task fetch_metadatas: :environment do
    ecosystems = OpenStax::Biglearn::Api.fetch_ecosystem_metadatas
                                        .fetch(:ecosystem_responses)
                                        .map do |ecosystem|
      Ecosystem.new uuid: ecosystem.fetch(:uuid)
    end

    result = Ecosystem.import ecosystems, validate: false,
                                          on_duplicate_key_ignore: { conflict_target: [ :uuid ] }

    Rails.logger.info do
      "Ecosystems: #{ecosystems.size} Received, #{result.num_inserts} New, #{Ecosystem.count} Total"
    end
  end
end

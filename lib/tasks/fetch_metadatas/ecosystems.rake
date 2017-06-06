namespace :fetch_metadatas do
  task ecosystems: :environment do
    Services::FetchEcosystemMetadatas::Service.process
  end
end

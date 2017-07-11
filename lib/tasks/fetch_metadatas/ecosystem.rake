namespace :fetch_metadatas do
  task ecosystem: :environment do
    Services::FetchEcosystemMetadatas::Service.process
  end
end

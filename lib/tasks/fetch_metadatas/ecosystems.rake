namespace :fetch_metadatas do
  task(ecosystems: :environment) { Services::FetchEcosystemMetadatas::Service.new.process }
end

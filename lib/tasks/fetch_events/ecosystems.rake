namespace :fetch_events do
  task ecosystems: :environment do
    Services::FetchEcosystemEvents::Service.process
  end
end

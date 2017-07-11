namespace :fetch_events do
  task ecosystem: :environment do
    Services::FetchEcosystemEvents::Service.process
  end
end

namespace :fetch_events do
  task ecosystems: :environment do
    Services::FetchEcosystemEvents::Service.new.process
  end
end

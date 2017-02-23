namespace :fetch_events do
  task(ecosystems: :environment) { Services::FetchEcosystemEvents::Service.new.process }
end

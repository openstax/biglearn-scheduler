namespace :fetch_events do
  task(worker: :environment) { Worker.new(:'fetch_events:all').start }
end

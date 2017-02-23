namespace :fetch_metadatas do
  task(worker: :environment) { Worker.new(:'fetch_metadatas:all').start }
end

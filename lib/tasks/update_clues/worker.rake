namespace :update_clues do
  task(worker: :environment) { Worker.new(:'update_clues:all').start }
end

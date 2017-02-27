namespace :update_exercises do
  task(worker: :environment) { Worker.new(:'update_exercises:all').start }
end

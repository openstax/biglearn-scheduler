namespace :update_exercises do
  task :all do
    task = Rake::Task[:'update_exercises:assignments']
    task.reenable
    task.invoke

    task = Rake::Task[:'update_exercises:practice_worst_areas']
    task.reenable
    task.invoke
  end
end

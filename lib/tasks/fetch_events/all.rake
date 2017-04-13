namespace :fetch_events do
  task :all do
    task = Rake::Task[:'fetch_events:ecosystems']
    task.reenable
    task.invoke

    task = Rake::Task[:'fetch_events:courses']
    task.reenable
    task.invoke
  end
end

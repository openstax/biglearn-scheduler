namespace :fetch_metadatas do
  task :all do
    task = Rake::Task[:'fetch_metadatas:ecosystems']
    task.reenable
    task.invoke

    task = Rake::Task[:'fetch_metadatas:courses']
    task.reenable
    task.invoke
  end
end

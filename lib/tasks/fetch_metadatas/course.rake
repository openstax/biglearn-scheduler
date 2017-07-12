namespace :fetch_metadatas do
  task course: :environment do
    Services::FetchCourseMetadatas::Service.process
  end
end

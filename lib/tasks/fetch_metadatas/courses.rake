namespace :fetch_metadatas do
  task courses: :environment do
    Services::FetchCourseMetadatas::Service.process
  end
end

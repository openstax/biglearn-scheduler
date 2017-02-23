namespace :fetch_metadatas do
  task(courses: :environment) { Services::FetchCourseMetadatas::Service.new.process }
end

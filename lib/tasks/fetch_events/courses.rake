namespace :fetch_events do
  task courses: :environment do
    Services::FetchCourseEvents::Service.process
  end
end

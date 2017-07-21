namespace :fetch_events do
  task course: :environment do
    Services::FetchCourseEvents::Service.process
  end
end

namespace :fetch_events do
  task courses: :environment do
    Services::FetchCourseEvents::Service.new.process
  end
end

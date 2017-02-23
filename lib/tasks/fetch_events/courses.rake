namespace :fetch_events do
  task(courses: :environment) { Services::FetchCourseEvents::Service.new.process }
end

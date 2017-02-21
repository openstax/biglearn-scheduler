RELEVANT_COURSE_EVENT_TYPES = [:create_course]

namespace :fetch_events do
  task courses: :environment do
    start_time = Time.now

    Rails.logger.tagged 'fetch_events:courses' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    course_event_requests = []
    ecosystem_uuids_by_course_uuid = Course.all.map do |course|
      course_event_requests << { course: course, event_types: RELEVANT_COURSE_EVENT_TYPES }

      [ course.uuid, course.ecosystem_uuid ]
    end.to_h
    course_event_responses = OpenStax::Biglearn::Api.fetch_course_events(course_event_requests)
                                                    .values.map(&:deep_symbolize_keys)
    course_events = course_event_responses.flat_map { |response| response.fetch(:events) }

    events_by_type = course_events.group_by { |event| event.fetch(:event_type) }

    # TODO: Actually do stuff

    courses = course_event_responses.map do |course_event_response|
      events = course_event_response.fetch(:events)
      next if events.empty?

      course_uuid = course_event_response.fetch(:course_uuid)
      ecosystem_uuid = ecosystem_uuids_by_course_uuid.fetch(course_uuid)
      events = course_event_response.fetch(:events)
      sequence_number = events.map{ |event| event.fetch(:sequence_number) }.max

      Course.new uuid: course_uuid, ecosystem_uuid: ecosystem_uuid, sequence_number: sequence_number
    end.compact

    result = Course.import courses, validate: false, on_duplicate_key_update: {
      conflict_target: [ :uuid ], column: [ :sequence_number ]
    }

    Rails.logger.tagged 'fetch_events:courses' do |logger|
      logger.info do
        "Received: #{course_events.size} events in #{courses.size} courses" +
        " - Failed: #{result.failed_instances.size} - Updated: #{result.num_inserts}" +
        " - Took: #{Time.now - start_time} second(s)"
      end
    end
  end
end

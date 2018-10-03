class Services::FetchCourseMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    course_responses = OpenStax::Biglearn::Api.fetch_course_metadatas.fetch(:course_responses)
    course_uuids = course_responses.map { |course_hash| course_hash.fetch(:uuid) }
    existing_course_uuids = Set.new Course.where(uuid: course_uuids).pluck(:uuid)

    courses = course_responses.map do |course_hash|
      course_uuid = course_hash.fetch(:uuid)
      next if existing_course_uuids.include? course_uuid

      Course.new uuid: course_uuid,
                 ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid),
                 sequence_number: 0,
                 course_excluded_exercise_uuids: [],
                 course_excluded_exercise_group_uuids: [],
                 global_excluded_exercise_uuids: [],
                 global_excluded_exercise_group_uuids: []
    end.compact

    # No sort needed because of on_duplicate_key_ignore
    result = Course.import(
      courses, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    )
    log(:debug) do
      response_count = course_responses.size
      existing_count = existing_course_uuids.size
      new_count = response_count - existing_count
      time = Time.current - start_time

      "Received: #{response_count} - Existing: #{existing_count}" +
      " - New: #{new_count} - Took: #{time} second(s)"
    end
  end
end

class Services::FetchCourseMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    course_responses = OpenStax::Biglearn::Api.fetch_course_metadatas.fetch(:course_responses)

    unless course_responses.empty?
      courses = course_responses.map do |course_hash|
        Course.new uuid: course_hash.fetch(:uuid),
                   ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid),
                   sequence_number: 0,
                   metadata_sequence_number: course_hash.fetch(:metadata_sequence_number),
                   course_excluded_exercise_uuids: [],
                   course_excluded_exercise_group_uuids: [],
                   global_excluded_exercise_uuids: [],
                   global_excluded_exercise_group_uuids: []
      end

      # No sort needed because of on_duplicate_key_ignore
      Course.import(
        courses, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
      )
    end

    log(:debug) do
      "Received: #{course_responses.size} - Took: #{Time.current - start_time} second(s)"
    end
  end
end

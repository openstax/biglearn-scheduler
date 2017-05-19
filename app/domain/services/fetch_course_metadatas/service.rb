class Services::FetchCourseMetadatas::Service < Services::ApplicationService
  def process
    start_time = Time.now
    Rails.logger.tagged 'FetchCourseMetadatas' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    courses = OpenStax::Biglearn::Api.fetch_course_metadatas
                                     .fetch(:course_responses)
                                     .map do |course_hash|
      Course.new uuid: course_hash.fetch(:uuid),
                 ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid),
                 sequence_number: 0,
                 course_excluded_exercise_uuids: [],
                 course_excluded_exercise_group_uuids: [],
                 global_excluded_exercise_uuids: [],
                 global_excluded_exercise_group_uuids: []
    end

    result = Course.import courses, validate: false,
                                    on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    Rails.logger.tagged 'FetchCourseMetadatas' do |logger|
      logger.debug do
        metadatas = courses.size
        conflicts = result.failed_instances.size
        successes = metadatas - conflicts
        total = Course.count
        time = Time.now - start_time

        "Received: #{metadatas} - Existing: #{conflicts} - New: #{successes}" +
        " - Total: #{total} - Took: #{time} second(s)"
      end
    end
  end
end

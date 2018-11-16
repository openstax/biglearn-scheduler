class Services::FetchCourseMetadatas::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    total_courses = 0

    loop do
      num_courses = Course.transaction do
        course_responses = OpenStax::Biglearn::Api.fetch_course_metadatas(
          max_num_metadatas: BATCH_SIZE
        ).fetch(:course_responses)
        courses_size = course_responses.size
        next 0 if courses_size == 0

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

        courses_size
      end

      total_courses += num_courses
      break if num_courses < BATCH_SIZE
    end

    log(:debug) { "Received: #{total_courses} - Took: #{Time.current - start_time} second(s)" }
  end
end

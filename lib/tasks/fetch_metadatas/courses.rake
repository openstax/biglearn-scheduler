namespace :fetch_metadatas do
  task courses: :environment do
    Rails.logger.info do
      @start_time = Time.now

      "Fetch course metadatas started at #{@start_time}"
    end

    courses = OpenStax::Biglearn::Api.fetch_course_metadatas
                                     .fetch(:course_responses)
                                     .map do |course_hash|
      Course.new uuid: course_hash.fetch(:uuid),
                 ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid)
    end

    result = Course.import courses, validate: false,
                                    on_duplicate_key_ignore: { conflict_target: [ :uuid ] }

    Rails.logger.info do
      "Courses: Received: #{courses.size} - Failed: #{result.failed_instances.size}" +
      " - New: #{result.num_inserts} - Total: #{Course.count}" +
      " - Took: #{Time.now - @start_time} second(s)"
    end
  end
end

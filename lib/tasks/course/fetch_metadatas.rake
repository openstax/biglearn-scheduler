namespace :course do
  task fetch_metadatas: :environment do
    courses = OpenStax::Biglearn::Api.fetch_course_metadatas
                                     .fetch(:course_responses)
                                     .map do |course_hash|
      Course.new uuid: course_hash.fetch(:uuid),
                 ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid)
    end

    result = Course.import courses, validate: false,
                                    on_duplicate_key_ignore: { conflict_target: [ :uuid ] }

    Rails.logger.info do
      "Courses: #{courses.size} received, #{result.num_inserts} new, #{Course.count} total"
    end
  end
end

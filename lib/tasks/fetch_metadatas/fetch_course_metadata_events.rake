namespace :fetch_metadatas do

  ## This rake task was created to manually fix sequence gaps
  # it does roughly the same thing as the service in
  # app/domain/services/fetch_course_metadatas/service.rb
  # but is invoked manually
  desc "import :count course metadata events at :offset"
  task :fetch_course_metadata_events, [:offset, :count] => [:environment] do |task, args|

    response = OpenStax::Biglearn::Api.client.send(
      :single_api_request,
      url: :fetch_course_metadatas,
      request: {
        max_num_metadatas: args[:count] || 1,
        metadata_sequence_number_offset: args[:offset]
      })

    courses = response[:course_responses].map do |course_hash|
      Course.new uuid: course_hash.fetch(:uuid),
                 ecosystem_uuid: course_hash.fetch(:initial_ecosystem_uuid),
                 sequence_number: 0,
                 metadata_sequence_number: course_hash.fetch(:metadata_sequence_number),
                 course_excluded_exercise_uuids: [],
                 course_excluded_exercise_group_uuids: [],
                 global_excluded_exercise_uuids: [],
                 global_excluded_exercise_group_uuids: []
    end

    Course.import(
      courses, validate: false, on_duplicate_key_ignore: { conflict_target: [ :uuid ] }
    )
  end
end

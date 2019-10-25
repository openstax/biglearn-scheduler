require 'rails_helper'

RSpec.describe OpenStax::Biglearn::Api, type: :external do
  context 'configuration' do
    it 'can be configured' do
      configuration = OpenStax::Biglearn::Api.configuration
      expect(configuration).to be_a(OpenStax::Biglearn::Api::Configuration)

      OpenStax::Biglearn::Api.configure do |config|
        expect(config).to eq configuration
      end
    end
  end

  context 'api calls' do
    before(:all) do
      DatabaseCleaner.start

      valid_ecosystem_event_types = [:create_ecosystem]
      @ecosystem_event_types = valid_ecosystem_event_types.sample(
        rand(valid_ecosystem_event_types.size + 1)
      )

      valid_course_event_types = [
        :create_course,
        :prepare_course_ecosystem,
        :update_course_ecosystem,
        :update_roster,
        :update_course_active_dates,
        :update_globally_excluded_exercises,
        :update_course_excluded_exercises,
        :create_update_assignment,
        :record_response
      ]
      @course_event_types = valid_course_event_types.sample(
        rand(valid_course_event_types.size + 1)
      )

      @book_container_uuid = SecureRandom.uuid
      @ecosystem = FactoryBot.create :ecosystem
      @course = FactoryBot.create :course
      @course_container = FactoryBot.create :course_container
      @student = FactoryBot.create :student
      @assignment = FactoryBot.create :assignment
      @exercises = rand(10).times.map { FactoryBot.create :exercise }

      random_sorted_numbers = 3.times.map { rand }.sort
      @clue_data = {
        minimum: random_sorted_numbers.first,
        most_likely: random_sorted_numbers.second,
        maximum: random_sorted_numbers.third,
        ecosystem_uuid: @ecosystem.uuid,
        is_real: [true, false].sample
      }
    end

    after(:all) { DatabaseCleaner.clean }

    [
      [
        :fetch_ecosystem_metadatas,
        -> { { max_num_metadatas: 1000 } },
        Hash
      ],
      [
        :fetch_course_metadatas,
        -> { { max_num_metadatas: 1000 } },
        Hash
      ],
      [
        :fetch_ecosystem_events,
        -> {
          [
            {
              event_types: @ecosystem_event_types,
              ecosystem: @ecosystem
            }
          ]
        },
        Hash
      ],
      [
        :fetch_course_events,
        -> {
          [
            {
              event_types: @course_event_types,
              course: @course
            }
          ]
        },
        Hash
      ],
      [
        :update_student_clues,
        -> {
          [
            {
              algorithm_name: 'local_query',
              student_uuid: @student.uuid,
              book_container_uuid: @book_container_uuid,
              clue_data: @clue_data
            }
          ]
        },
        Hash
      ],
      [
        :update_teacher_clues,
        -> {
          [
            {
              algorithm_name: 'local_query',
              course_container_uuid: @course_container.uuid,
              book_container_uuid: @book_container_uuid,
              clue_data: @clue_data
            }
          ]
        },
        Hash
      ],
      [
        :update_assignment_pes,
        -> {
          [
            {
              algorithm_name: 'local_query',
              assignment_uuid: @assignment.uuid,
              exercise_uuids: @exercises.map(&:uuid),
              spy_info: {}
            }
          ]
        },
        Hash
      ],
      [
        :update_assignment_spes,
        -> {
          [
            {
              algorithm_name: 'local_query_student_driven',
              assignment_uuid: @assignment.uuid,
              exercise_uuids: @exercises.map(&:uuid),
              spy_info: {}
            }
          ]
        },
        Hash
      ],
      [
        :update_practice_worst_areas,
        -> {
          [
            {
              algorithm_name: 'local_query',
              student_uuid: @student.uuid,
              exercise_uuids: @exercises.map(&:uuid),
              spy_info: {}
            }
          ]
        },
        Hash
      ]
    ].each do |method, requests_proc, result_class|
      it "delegates #{method} to the client implementation and returns the response" do
        requests = requests_proc.nil? ? nil : instance_exec(&requests_proc)

        expect(OpenStax::Biglearn::Api.client).to receive(method).and_call_original

        results = requests.nil? ? OpenStax::Biglearn::Api.send(method) :
                                  OpenStax::Biglearn::Api.send(method, requests)

        results = results.values if requests.is_a?(Array) && results.is_a?(Hash)

        [results].flatten.each { |result| expect(result).to be_a result_class }
      end
    end
  end
end

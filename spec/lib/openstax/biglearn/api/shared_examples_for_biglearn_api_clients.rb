require 'rails_helper'
require 'vcr_helper'

RSpec.shared_examples 'a biglearn api client' do
  let(:configuration) { OpenStax::Biglearn::Api.configuration }
  subject(:client)    { described_class.new(configuration) }

  let(:clue_matcher)  do
    {
      min: kind_of(Float),
      most_likely: kind_of(Float),
      max: kind_of(Float),
      ecosystem_uuid: kind_of(String),
      is_real: included_in([true, false])
    }
  end

  valid_ecosystem_event_types = [:create_ecosystem]
  ecosystem_event_types = valid_ecosystem_event_types.sample 1

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
  course_event_types = valid_course_event_types.sample rand(valid_course_event_types.size) + 1

  dummy_book_container_uuid = SecureRandom.uuid
  dummy_ecosystem = OpenStruct.new uuid: SecureRandom.uuid, sequence_number: 42
  dummy_course = OpenStruct.new uuid: SecureRandom.uuid, sequence_number: 42
  dummy_course_container = OpenStruct.new uuid: SecureRandom.uuid
  dummy_student = OpenStruct.new uuid: SecureRandom.uuid
  dummy_assignment = OpenStruct.new uuid: SecureRandom.uuid
  dummy_exercises = rand(10).times.map do
    OpenStruct.new uuid: SecureRandom.uuid, group_uuid: SecureRandom.uuid
  end

  random_sorted_numbers = 3.times.map { rand }.sort
  dummy_clue_data = {
    minimum: random_sorted_numbers.first,
    most_likely: random_sorted_numbers.second,
    maximum: random_sorted_numbers.third,
    is_real: [true, false].sample,
    ecosystem_uuid: dummy_ecosystem.uuid
  }

  when_tagged_with_vcr = { vcr: ->(v) { !!v } }

  before(:all, when_tagged_with_vcr) do
    VCR.configure do |config|
      config.define_cassette_placeholder('<ECOSYSTEM EVENT TYPES>') { ecosystem_event_types       }
      config.define_cassette_placeholder('<COURSE EVENT TYPES>'   ) { course_event_types          }
      config.define_cassette_placeholder('<BOOK CONTAINER UUID>'  ) { dummy_book_container_uuid   }
      config.define_cassette_placeholder('<ECOSYSTEM UUID>'       ) { dummy_ecosystem.uuid        }
      config.define_cassette_placeholder('<COURSE UUID>'          ) { dummy_course.uuid           }
      config.define_cassette_placeholder('<COURSE CONTAINER UUID>') { dummy_course_container.uuid }
      config.define_cassette_placeholder('<STUDENT UUID>'         ) { dummy_student.uuid          }
      config.define_cassette_placeholder('<ASSIGNMENT UUID>'      ) { dummy_assignment.uuid       }
      config.define_cassette_placeholder('<EXERCISE UUIDS>'       ) { dummy_exercises.map(&:uuid) }
    end
  end

  [
    [
      :fetch_ecosystem_metadatas,
      nil,
      []
    ],
    [
      :fetch_course_metadatas,
      nil,
      []
    ],
    [
      :fetch_ecosystem_events,
      [
        {
          event_types: ecosystem_event_types,
          ecosystem: dummy_ecosystem
        }
      ],
      [
        {
          ecosystem_uuid: dummy_ecosystem.uuid,
          events: [],
          is_stopped_at_gap: false
        }
      ]
    ],
    [
      :fetch_course_events,
      [
        {
          event_types: course_event_types,
          course: dummy_course
        }
      ],
      [
        {
          course_uuid: dummy_course.uuid,
          events: [],
          is_stopped_at_gap: false
        }
      ]
    ],
    [
      :update_student_clues,
      [
        {
          student: dummy_student,
          book_container_uuid: dummy_book_container_uuid,
          clue_data: dummy_clue_data
        }
      ],
      [
        { update_status: 'accepted' }
      ]
    ],
    [
      :update_teacher_clues,
      [
        {
          course_container: dummy_course_container,
          book_container_uuid: dummy_book_container_uuid,
          clue_data: dummy_clue_data
        }
      ],
      [
        { update_status: 'accepted' }
      ]
    ],
    [
      :update_assignment_pes,
      [
        {
          assignment: dummy_assignment,
          book_container_uuid: dummy_book_container_uuid,
          exercises: dummy_exercises
        }
      ],
      [
        { update_status: 'accepted' }
      ]
    ],
    [
      :update_assignment_spes,
      [
        {
          assignment: dummy_assignment,
          book_container_uuid: dummy_book_container_uuid,
          exercises: dummy_exercises
        }
      ],
      [
        { update_status: 'accepted' }
      ]
    ],
    [
      :update_practice_worst_areas,
      [
        {
          student: dummy_student,
          exercises: dummy_exercises
        }
      ],
      [
        { update_status: 'accepted' }
      ]
    ]
  ].group_by(&:first).each do |method, examples|
    context "##{method}" do
      examples.each_with_index do |(method, requests, expected_responses, uuid_key), index|
        uuid_key ||= :request_uuid

        if requests.is_a?(Array)
          request_uuids = requests.map { SecureRandom.uuid }
          requests = requests.each_with_index.map do |request, index|
            request.merge(uuid_key => request_uuids[index])
          end

          before(:all, when_tagged_with_vcr) do
            VCR.configure do |config|
              requests.each_with_index do |request, request_index|
                config.define_cassette_placeholder(
                  "<#{method.to_s.upcase} EXAMPLE #{index + 1} REQUEST #{request_index + 1} UUID>"
                ) { request_uuids[index] }
              end
            end
          end
        end

        it "returns the expected response for the #{(index + 1).ordinalize} set of requests" do
          expected_responses = instance_exec(&expected_responses) if expected_responses.is_a?(Proc)
          expected_responses = expected_responses.each_with_index.map do |expected_response, index|
            expected_response = instance_exec(&expected_response) if expected_response.is_a?(Proc)
            expected_response.merge(uuid_key => request_uuids[index])
          end if requests.is_a?(Array)

          actual_responses = requests.nil? ? client.send(method) : client.send(method, requests)

          expect([actual_responses].flatten).to match_array([expected_responses].flatten)
        end
      end
    end
  end
end

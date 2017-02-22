require 'rake_helper'

ASSIGNMENT_TYPES = [ 'reading', 'homework', 'practice', 'concept-coach' ]

RSpec.describe 'fetch_events:ecosystems', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  context 'with no events' do
    it 'does not modify any records' do
      expect { subject.invoke }.to  not_change { Ecosystem.count }
                               .and not_change { ExercisePool.count }
                               .and not_change { Exercise.count }
    end
  end

  context 'with an exiting ecosystem and ecosystem events' do
    let!(:ecosystem)                { FactoryGirl.create :ecosystem, sequence_number: 0 }

    context 'create_ecosystem events' do
      let(:num_los)                   { rand(5)  + 1 }
      let(:los)                       do
        num_los.times.map { Faker::Name.name.downcase.gsub('. ', ':').gsub(' ', '-') }
      end

      let(:num_exercises)             { rand(10) + 1 }
      let(:exercises)                 do
        num_exercises.times.map do
          {
            exercise_uuid: SecureRandom.uuid,
            group_uuid: SecureRandom.uuid,
            version: rand(10) + 1,
            los: los.sample(rand(num_los) + 1)
          }
        end
      end

      let(:num_chapters)              { rand(10) + 1 }
      let(:num_pages_per_chapter)     { rand(6)  + 2 }
      let(:num_pools_per_container)   { rand(5)  + 1 }
      let(:book_containers)           do
        num_chapters.times.flat_map do
          container_uuid = SecureRandom.uuid

          [
            {
              container_uuid: container_uuid,
              container_parent_uuid: ecosystem.uuid,
              container_cnx_identity: "#{SecureRandom.uuid}@#{rand(10) + 1}.#{rand(10)}",
              pools: num_pools_per_container.times.map do
                assignment_types = ASSIGNMENT_TYPES.sample(rand(ASSIGNMENT_TYPES.size + 1))

                {
                  use_for_clue: [true, false].sample,
                  use_for_personalized_for_assignment_types: assignment_types,
                  exercise_uuids: exercises.sample(rand(num_exercises + 1))
                }
              end
            }
          ] + num_pages_per_chapter.times.map do
            {
              container_uuid: SecureRandom.uuid,
              container_parent_uuid: container_uuid,
              container_cnx_identity: "#{SecureRandom.uuid}@#{rand(10) + 1}.#{rand(10)}",
              pools: num_pools_per_container.times.map do
                assignment_types = ASSIGNMENT_TYPES.sample(rand(ASSIGNMENT_TYPES.size + 1))

                {
                  use_for_clue: [true, false].sample,
                  use_for_personalized_for_assignment_types: assignment_types,
                  exercise_uuids: exercises.sample(rand(num_exercises + 1))
                }
              end
            }
          end
        end
      end

      let(:book)                      do
        {
          cnx_identity: "#{SecureRandom.uuid}@#{rand(10) + 1}.#{rand(10)}",
          contents: book_containers
        }
      end

      let(:create_ecosystem)          do
        {
          sequence_number: 0,
          event_uuid: SecureRandom.uuid,
          event_type: 'create_ecosystem',
          event_data: { book: book, exercises: exercises }
        }
      end

      let(:ecosystem_events)          { [ create_ecosystem ] }
      let(:ecosystem_events_response) do
        {
          request_uuid: SecureRandom.uuid,
          ecosystem_uuid: ecosystem.uuid,
          events: ecosystem_events,
          is_stopped_at_gap: false
        }
      end

      it 'creates ExercisePools and Exercises for the Ecosystem' do
        expect(OpenStax::Biglearn::Api).to receive(:fetch_ecosystem_events) do |requests|
          { requests.first => ecosystem_events_response }
        end

        num_pages = num_chapters * num_pages_per_chapter
        num_book_containers = num_chapters + num_pages
        num_pools = num_pools_per_container * num_book_containers

        expect { subject.invoke }.to  not_change { Ecosystem.count }
                                 .and change { ExercisePool.count }.by(num_pools)
                                 .and change { Exercise.count }.by(num_exercises)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::FetchEcosystemEvents::Service, type: :service do
  subject { described_class.new }

  context 'with no events' do
    it 'does not modify any records' do
      expect { subject.process }.to  not_change { Ecosystem.count }
                                .and not_change { ExercisePool.count }
                                .and not_change { Exercise.count }
                                .and not_change { EcosystemExercise.count }
    end
  end

  context 'with an existing ecosystem and ecosystem events' do
    let!(:ecosystem)                { FactoryGirl.create :ecosystem, sequence_number: 0 }

    let(:sequence_number)           { 0 }
    let(:event_uuid)                { SecureRandom.uuid }

    let(:ecosystem_event)           do
      {
        sequence_number: sequence_number,
        event_uuid: event_uuid,
        event_type: event_type,
        event_data: event_data
      }
    end

    let(:ecosystem_events)          { [ ecosystem_event ] }

    let(:ecosystem_events_response) do
      {
        request_uuid: SecureRandom.uuid,
        ecosystem_uuid: ecosystem.uuid,
        events: ecosystem_events,
        is_gap: false,
        is_end: true
      }
    end

    before                          do
      expect(OpenStax::Biglearn::Api).to receive(:fetch_ecosystem_events) do |requests|
        { requests.first => ecosystem_events_response }
      end
    end

    context 'create_ecosystem events' do
      let(:event_type)              { 'create_ecosystem' }

      let(:num_los)                 { rand(5)  + 1 }
      let(:los)                     do
        num_los.times.map { Faker::Name.name.downcase.gsub('. ', ':').gsub(' ', '-') }
      end

      let(:num_exercises)           { rand(10) + 1 }
      let(:exercises)               do
        num_exercises.times.map do
          {
            exercise_uuid: SecureRandom.uuid,
            group_uuid: SecureRandom.uuid,
            version: rand(10) + 1,
            los: los.sample(rand(num_los) + 1)
          }
        end
      end
      let!(:existing_exercise)      do
        FactoryGirl.create :exercise, uuid: exercises.first.fetch(:exercise_uuid)
      end

      let(:num_chapters)            { rand(10) + 1 }
      let(:num_pages_per_chapter)   { rand(6)  + 2 }
      let(:num_pools_per_container) { rand(5)  + 1 }
      let(:book_containers)         do
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

      let(:book)                    do
        {
          cnx_identity: "#{SecureRandom.uuid}@#{rand(10) + 1}.#{rand(10)}",
          contents: book_containers
        }
      end

      let(:event_data)              do
        {
          ecosystem_uuid: ecosystem.uuid,
          sequence_number: sequence_number,
          book: book,
          exercises: exercises
        }
      end

      it 'creates ExercisePools and Exercises for the Ecosystem' do
        num_pages = num_chapters * num_pages_per_chapter
        num_book_containers = num_chapters + num_pages
        num_pools = num_pools_per_container * num_book_containers

        expect { subject.process }.to  not_change { Ecosystem.count }
                                  .and change { ExercisePool.count }.by(num_pools)
                                  .and change { Exercise.count }.by(num_exercises - 1)
                                  .and change { EcosystemExercise.count }.by(num_exercises)
                                  .and change { ecosystem.reload.sequence_number }
                                                .from(0).to(sequence_number + 1)
      end
    end
  end
end

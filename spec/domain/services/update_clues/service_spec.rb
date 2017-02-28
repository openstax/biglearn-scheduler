require 'rails_helper'

RSpec.describe Services::UpdateClues::Service, type: :service do
  subject { described_class.new }

  context 'with no Responses' do
    it 'does not update any CLUes' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to not_change { Response.count }
    end
  end

  context 'with existing Ecosystems, Course, Students and Responses' do
    before(:all) do
      DatabaseCleaner.start

      @ecosystem_1 = FactoryGirl.create :ecosystem
      @ecosystem_2 = FactoryGirl.create :ecosystem

      @course = FactoryGirl.create :course, ecosystem_uuid: @ecosystem_2.uuid

      @cc_1 = FactoryGirl.create :course_container, course_uuid: @course.uuid,
                                                    student_uuids: []
      @cc_2 = FactoryGirl.create :course_container, course_uuid: @course.uuid,
                                                    student_uuids: []

      @student_1 = FactoryGirl.create :student, course_uuid: @course.uuid,
                                                course_container_uuids: [ @cc_1.uuid ]
      @student_2 = FactoryGirl.create :student, course_uuid: @course.uuid,
                                                course_container_uuids: [ @cc_1.uuid ]

      @cc_1.update_attribute :student_uuids, [ @student_1.uuid, @student_2.uuid ]

      @exercise_1 = FactoryGirl.create :exercise
      @exercise_2 = FactoryGirl.create :exercise
      @exercise_3 = FactoryGirl.create :exercise
      @exercise_4 = FactoryGirl.create :exercise
      @exercise_5 = FactoryGirl.create :exercise

      @response_1 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_1.uuid
      FactoryGirl.create :response_clue, uuid: @response_1.uuid
      @response_2 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_2.uuid
      FactoryGirl.create :response_clue, uuid: @response_2.uuid
      @response_3 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_3.uuid
      FactoryGirl.create :response_clue, uuid: @response_3.uuid
      @response_4 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_4.uuid
      @response_5 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_5.uuid
      @response_6 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_1.uuid
      FactoryGirl.create :response_clue, uuid: @response_6.uuid
      @response_7 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_2.uuid
      FactoryGirl.create :response_clue, uuid: @response_7.uuid
      @response_8 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_3.uuid
      @response_9 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_4.uuid
      @response_10 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_5.uuid

      @unprocessed_responses = [ @response_4, @response_5, @response_8, @response_9, @response_10 ]
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Response objects as processed' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect do
        subject.process
      end.to  not_change { Response.count     }
         .and change     { ResponseClue.count }.by(@unprocessed_responses.size)

      new_response_clue_uuids = ResponseClue.order(:created_at)
                                            .last(@unprocessed_responses.size)
                                            .map(&:uuid)
      expect(@unprocessed_responses.map(&:uuid)).to match_array(new_response_clue_uuids)
    end

    context 'with other associated records' do
      before(:all) do
        DatabaseCleaner.start

        # Old ecosystem (unused)
        old_ep = FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_1.uuid,
                                                    exercise_uuids: [ @exercise_1.uuid,
                                                                      @exercise_2.uuid,
                                                                      @exercise_3.uuid,
                                                                      @exercise_4.uuid,
                                                                      @exercise_5.uuid ],
                                                    use_for_clue: true

        # New ecosystem
        @ep_1 = FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2.uuid,
                                                   exercise_uuids: [ @exercise_1.uuid,
                                                                     @exercise_2.uuid,
                                                                     @exercise_3.uuid ],
                                                   use_for_clue: true
        @ep_2 = FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2.uuid,
                                                   exercise_uuids: [ @exercise_4.uuid,
                                                                     @exercise_5.uuid ],
                                                   use_for_clue: true

        # Not used for CLUes
        FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2.uuid,
                                           book_container_uuid: @ep_1.book_container_uuid,
                                           exercise_uuids: [ @exercise_4.uuid,
                                                             @exercise_5.uuid ],
                                           use_for_clue: false
        FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2.uuid,
                                           book_container_uuid: @ep_2.book_container_uuid,
                                           exercise_uuids: [ @exercise_1.uuid,
                                                             @exercise_2.uuid,
                                                             @exercise_3.uuid ],
                                           use_for_clue: false

        old_book_container_uuids = [ SecureRandom.uuid, old_ep.book_container_uuid ]
        book_container_uuids_1 = [ SecureRandom.uuid, @ep_1.book_container_uuid ]
        book_container_uuids_2 = [ SecureRandom.uuid, @ep_2.book_container_uuid ]

        # Old ecosystem (unused)
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_1.uuid,
                                                exercise_group_uuid: @exercise_1.group_uuid,
                                                book_container_uuids: old_book_container_uuids
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_1.uuid,
                                                exercise_group_uuid: @exercise_2.group_uuid,
                                                book_container_uuids: old_book_container_uuids
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_1.uuid,
                                                exercise_group_uuid: @exercise_3.group_uuid,
                                                book_container_uuids: old_book_container_uuids

        # New ecosystem
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_2.uuid,
                                                exercise_group_uuid: @exercise_1.group_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_2.uuid,
                                                exercise_group_uuid: @exercise_2.group_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_2.uuid,
                                                exercise_group_uuid: @exercise_3.group_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_2.uuid,
                                                exercise_group_uuid: @exercise_4.group_uuid,
                                                book_container_uuids: book_container_uuids_2
        FactoryGirl.create :ecosystem_exercise, ecosystem_uuid: @ecosystem_2.uuid,
                                                exercise_group_uuid: @exercise_5.group_uuid,
                                                book_container_uuids: book_container_uuids_2
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'sends the correct updated CLUes to biglearn-api' do
        student_uuids = [ @student_1.uuid, @student_2.uuid ]
        book_container_uuids = [ @ep_1.book_container_uuid, @ep_2.book_container_uuid ]

        expect(OpenStax::Biglearn::Api).to receive(:update_student_clues) do |requests|
          expect(requests.size).to eq 3

          requests.each do |request|
            expect(request.fetch :student_uuid).to be_in student_uuids
            expect(request.fetch :book_container_uuid).to be_in book_container_uuids
          end

          clue_data_1 = requests.find do |request|
            request.fetch(:student_uuid) == @student_1.uuid &&
            request.fetch(:book_container_uuid) == @ep_2.book_container_uuid
          end.fetch :clue_data
          expect(clue_data_1).to(
            eq subject.send(:calculate_clue_data, [ true, true ])
                      .merge(ecosystem_uuid: @ecosystem_2.uuid)
          )

          clue_data_2 = requests.find do |request|
            request.fetch(:student_uuid) == @student_2.uuid &&
            request.fetch(:book_container_uuid) == @ep_1.book_container_uuid
          end.fetch :clue_data
          expect(clue_data_2).to(
            eq subject.send(:calculate_clue_data, [ false, true, true ])
                      .merge(ecosystem_uuid: @ecosystem_2.uuid)
          )

          clue_data_3 = requests.find do |request|
            request.fetch(:student_uuid) == @student_2.uuid &&
            request.fetch(:book_container_uuid) == @ep_2.book_container_uuid
          end.fetch :clue_data
          expect(clue_data_3).to(
            eq subject.send(:calculate_clue_data, [ true, false ])
                      .merge(ecosystem_uuid: @ecosystem_2.uuid)
          )
        end

        expect(OpenStax::Biglearn::Api).to receive(:update_teacher_clues) do |requests|
          expect(requests.size).to eq 2

          requests.each do |request|
            expect(request.fetch :course_container_uuid).to eq @cc_1.uuid
            expect(request.fetch :book_container_uuid).to be_in book_container_uuids
          end

          clue_data_1 = requests.find do |request|
            request.fetch(:book_container_uuid) == @ep_1.book_container_uuid
          end.fetch :clue_data
          expect(clue_data_1).to(
            eq subject.send(:calculate_clue_data, [ true, false, true, false, true, true ])
                      .merge(ecosystem_uuid: @ecosystem_2.uuid)
          )

          clue_data_2 = requests.find do |request|
            request.fetch(:book_container_uuid) == @ep_2.book_container_uuid
          end.fetch :clue_data
          expect(clue_data_2).to(
            eq subject.send(:calculate_clue_data, [ true, true, true, false ])
                      .merge(ecosystem_uuid: @ecosystem_2.uuid)
          )
        end

        expect do
          subject.process
        end.to  not_change { Response.count     }
           .and change     { ResponseClue.count }.by(@unprocessed_responses.size)

        new_response_clue_uuids = ResponseClue.order(:created_at)
                                              .last(@unprocessed_responses.size)
                                              .map(&:uuid)
        expect(@unprocessed_responses.map(&:uuid)).to match_array(new_response_clue_uuids)
      end
    end
  end
end

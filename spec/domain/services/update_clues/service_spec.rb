require 'rails_helper'

RSpec.describe Services::UpdateClues::Service, type: :service do
  subject { described_class.new }

  context 'with no Responses' do
    it 'does not update any CLUes' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect { subject.process }.to  not_change { Response.count }
                                .and not_change { Trial.count    }
    end
  end

  context 'with existing Responses and Trials' do
    before(:all) do
      DatabaseCleaner.start

      @response_1 = FactoryGirl.create :response, used_in_clues: true,
                                                  is_correct: true
      @student_1_uuid = @response_1.student_uuid
      @exercise_1_uuid = @response_1.exercise_uuid
      @response_2 = FactoryGirl.create :response, used_in_clues: true,
                                                  is_correct: false,
                                                  student_uuid: @student_1_uuid
      @exercise_2_uuid = @response_2.exercise_uuid
      @response_3 = FactoryGirl.create :response, used_in_clues: true,
                                                  is_correct: true,
                                                  student_uuid: @student_1_uuid
      @exercise_3_uuid = @response_3.exercise_uuid
      @response_4 = FactoryGirl.create :response, used_in_clues: false,
                                                  is_correct: true,
                                                  student_uuid: @student_1_uuid
      @exercise_4_uuid = @response_4.exercise_uuid
      @response_5 = FactoryGirl.create :response, used_in_clues: false,
                                                  is_correct: true,
                                                  student_uuid: @student_1_uuid
      @exercise_5_uuid = @response_5.exercise_uuid
      @response_6 = FactoryGirl.create :response, used_in_clues: true,
                                                  is_correct: false,
                                                  exercise_uuid: @exercise_1_uuid
      @student_2_uuid = @response_6.student_uuid
      @response_7 = FactoryGirl.create :response, used_in_clues: true,
                                                  is_correct: true,
                                                  exercise_uuid: @exercise_2_uuid,
                                                  student_uuid: @student_2_uuid
      @response_8 = FactoryGirl.create :response, used_in_clues: false,
                                                  is_correct: true,
                                                  exercise_uuid: @exercise_3_uuid,
                                                  student_uuid: @student_2_uuid
      @response_9 = FactoryGirl.create :response, used_in_clues: false,
                                                  is_correct: true,
                                                  exercise_uuid: @exercise_4_uuid,
                                                  student_uuid: @student_2_uuid
      @response_10 = FactoryGirl.create :response, used_in_clues: false,
                                                   is_correct: false,
                                                   exercise_uuid: @exercise_5_uuid,
                                                   student_uuid: @student_2_uuid

      @trial_1 = FactoryGirl.create :trial, uuid: @response_1.uuid
      @ecosystem_1_uuid = @trial_1.ecosystem_uuid
      @trial_2 = FactoryGirl.create :trial, uuid: @response_2.uuid,
                                            ecosystem_uuid: @ecosystem_1_uuid
      @trial_3 = FactoryGirl.create :trial, uuid: @response_3.uuid,
                                            ecosystem_uuid: @ecosystem_1_uuid
      @trial_4 = FactoryGirl.create :trial, uuid: @response_4.uuid
      @ecosystem_2_uuid = @trial_1.ecosystem_uuid
      @trial_5 = FactoryGirl.create :trial, uuid: @response_5.uuid,
                                            ecosystem_uuid: @ecosystem_2_uuid
      @trial_6 = FactoryGirl.create :trial, uuid: @response_6.uuid,
                                            ecosystem_uuid: @ecosystem_1_uuid
      @trial_7 = FactoryGirl.create :trial, uuid: @response_7.uuid,
                                            ecosystem_uuid: @ecosystem_1_uuid
      @trial_8 = FactoryGirl.create :trial, uuid: @response_8.uuid,
                                            ecosystem_uuid: @ecosystem_1_uuid
      @trial_9 = FactoryGirl.create :trial, uuid: @response_9.uuid,
                                            ecosystem_uuid: @ecosystem_2_uuid
      @trial_10 = FactoryGirl.create :trial, uuid: @response_10.uuid,
                                             ecosystem_uuid: @ecosystem_2_uuid
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Response objects as processed' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_student_clues)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_teacher_clues)

      expect do
        subject.process
      end.to  not_change { Response.count                    }
         .and not_change { Trial.count                       }
         .and not_change { @response_1.reload.used_in_clues  }
         .and not_change { @response_2.reload.used_in_clues  }
         .and not_change { @response_3.reload.used_in_clues  }
         .and change     { @response_4.reload.used_in_clues  }.from(false).to(true)
         .and change     { @response_5.reload.used_in_clues  }.from(false).to(true)
         .and not_change { @response_6.reload.used_in_clues  }
         .and not_change { @response_7.reload.used_in_clues  }
         .and change     { @response_8.reload.used_in_clues  }.from(false).to(true)
         .and change     { @response_9.reload.used_in_clues  }.from(false).to(true)
         .and change     { @response_10.reload.used_in_clues }.from(false).to(true)
    end

    context 'with other associated records' do
      before(:all) do
        DatabaseCleaner.start

        course = FactoryGirl.create :course, ecosystem_uuid: @ecosystem_2_uuid

        cc_1 = FactoryGirl.create :course_container, course_uuid: course.uuid,
                                                     student_uuids: [
                                                       @student_1_uuid,
                                                       @student_2_uuid
                                                     ]
        @course_container_1_uuid = cc_1.uuid
        cc_2 = FactoryGirl.create :course_container, course_uuid: course.uuid,
                                                     student_uuids: []
        @course_container_2_uuid = cc_2.uuid

        FactoryGirl.create :student, uuid: @student_1_uuid,
                                     course_container_uuids: [ @course_container_1_uuid ]
        FactoryGirl.create :student, uuid: @student_2_uuid,
                                     course_container_uuids: [ @course_container_1_uuid ]

        FactoryGirl.create :exercise, uuid: @exercise_1_uuid
        FactoryGirl.create :exercise, uuid: @exercise_2_uuid
        FactoryGirl.create :exercise, uuid: @exercise_3_uuid
        FactoryGirl.create :exercise, uuid: @exercise_4_uuid
        FactoryGirl.create :exercise, uuid: @exercise_5_uuid

        ep_1 = FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_1_uuid,
                                                  exercise_uuids: [ @exercise_1_uuid,
                                                                    @exercise_2_uuid,
                                                                    @exercise_3_uuid ],
                                                  use_for_clue: true
        @book_container_1_uuid = ep_1.book_container_uuid
        ep_2 = FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2_uuid,
                                                  exercise_uuids: [ @exercise_4_uuid,
                                                                    @exercise_5_uuid ],
                                                  use_for_clue: true
        @book_container_2_uuid = ep_2.book_container_uuid

        FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_1_uuid,
                                           book_container_uuid: @book_container_1_uuid,
                                           exercise_uuids: [ @exercise_4_uuid,
                                                             @exercise_5_uuid ],
                                           use_for_clue: false
        FactoryGirl.create :exercise_pool, ecosystem_uuid: @ecosystem_2_uuid,
                                           book_container_uuid: @book_container_2_uuid,
                                           exercise_uuids: [ @exercise_1_uuid,
                                                             @exercise_2_uuid,
                                                             @exercise_3_uuid ],
                                           use_for_clue: false

        book_container_uuids_1 = [ SecureRandom.uuid, @book_container_1_uuid ]
        book_container_uuids_2 = [ SecureRandom.uuid, @book_container_2_uuid ]

        FactoryGirl.create :ecosystem_exercise, exercise_uuid: @exercise_1_uuid,
                                                ecosystem_uuid: @ecosystem_1_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, exercise_uuid: @response_2.exercise_uuid,
                                                ecosystem_uuid: @ecosystem_1_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, exercise_uuid: @response_3.exercise_uuid,
                                                ecosystem_uuid: @ecosystem_1_uuid,
                                                book_container_uuids: book_container_uuids_1
        FactoryGirl.create :ecosystem_exercise, exercise_uuid: @response_4.exercise_uuid,
                                                ecosystem_uuid: @ecosystem_2_uuid,
                                                book_container_uuids: book_container_uuids_2
        FactoryGirl.create :ecosystem_exercise, exercise_uuid: @response_5.exercise_uuid,
                                                ecosystem_uuid: @ecosystem_2_uuid,
                                                book_container_uuids: book_container_uuids_2
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'sends the correct updated CLUes to biglearn-api' do
        student_uuids = [ @student_1_uuid, @student_2_uuid ]
        book_container_uuids = [ @book_container_1_uuid, @book_container_2_uuid ]

        expect(OpenStax::Biglearn::Api).to receive(:update_student_clues) do |requests|
          expect(requests.size).to eq 3

          requests.each do |request|
            expect(request.fetch :student_uuid).to be_in student_uuids
            expect(request.fetch :book_container_uuid).to be_in book_container_uuids
          end

          clue_data_1 = requests.find do |request|
            request.fetch(:student_uuid) == @student_1_uuid &&
            request.fetch(:book_container_uuid) == @book_container_2_uuid
          end.fetch :clue_data
          expect(clue_data_1).to(
            eq subject.send(:calculate_clue_data, responses: [ true, true ])
                      .merge(ecosystem_uuid: @ecosystem_2_uuid)
          )

          clue_data_2 = requests.find do |request|
            request.fetch(:student_uuid) == @student_2_uuid &&
            request.fetch(:book_container_uuid) == @book_container_1_uuid
          end.fetch :clue_data
          expect(clue_data_2).to(
            eq subject.send(:calculate_clue_data, responses: [ false, true, true ])
                      .merge(ecosystem_uuid: @ecosystem_1_uuid)
          )

          clue_data_3 = requests.find do |request|
            request.fetch(:student_uuid) == @student_2_uuid &&
            request.fetch(:book_container_uuid) == @book_container_2_uuid
          end.fetch :clue_data
          expect(clue_data_3).to(
            eq subject.send(:calculate_clue_data, responses: [ true, false ])
                      .merge(ecosystem_uuid: @ecosystem_2_uuid)
          )
        end

        expect(OpenStax::Biglearn::Api).to receive(:update_teacher_clues) do |requests|
          expect(requests.size).to eq 2

          requests.each do |request|
            expect(request.fetch :course_container_uuid).to eq @course_container_1_uuid
            expect(request.fetch :book_container_uuid).to be_in book_container_uuids
          end

          clue_data_1 = requests.find do |request|
            request.fetch(:book_container_uuid) == @book_container_1_uuid
          end.fetch :clue_data
          expect(clue_data_1).to(
            eq subject.send(
              :calculate_clue_data, responses: [ true, false, true, false, true, true ]
            ).merge(ecosystem_uuid: @ecosystem_1_uuid)
          )

          clue_data_2 = requests.find do |request|
            request.fetch(:book_container_uuid) == @book_container_2_uuid
          end.fetch :clue_data
          expect(clue_data_2).to(
            eq subject.send(
              :calculate_clue_data, responses: [ true, true, true, false ]
            ).merge(ecosystem_uuid: @ecosystem_2_uuid)
          )
        end

        expect do
          subject.process
        end.to  not_change { Response.count                    }
           .and not_change { Trial.count                       }
           .and not_change { @response_1.reload.used_in_clues  }
           .and not_change { @response_2.reload.used_in_clues  }
           .and not_change { @response_3.reload.used_in_clues  }
           .and change     { @response_4.reload.used_in_clues  }.from(false).to(true)
           .and change     { @response_5.reload.used_in_clues  }.from(false).to(true)
           .and not_change { @response_6.reload.used_in_clues  }
           .and not_change { @response_7.reload.used_in_clues  }
           .and change     { @response_8.reload.used_in_clues  }.from(false).to(true)
           .and change     { @response_9.reload.used_in_clues  }.from(false).to(true)
           .and change     { @response_10.reload.used_in_clues }.from(false).to(true)
      end
    end
  end
end

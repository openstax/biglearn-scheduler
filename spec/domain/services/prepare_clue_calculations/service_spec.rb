require 'rails_helper'

RSpec.describe Services::PrepareClueCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no Responses' do
    it 'does not update any CLUes' do
      expect { subject.process }.to  not_change { Response.count                        }
                                .and not_change { StudentClueCalculation.count          }
                                .and not_change { TeacherClueCalculation.count          }
                                .and not_change { AlgorithmStudentClueCalculation.count }
                                .and not_change { AlgorithmTeacherClueCalculation.count }
                                .and not_change { StudentPeCalculation.count            }
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
                                       exercise_uuid: @exercise_1.uuid,
                                       used_in_clue_calculations: true
      @response_2 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_2.uuid,
                                       used_in_clue_calculations: true
      @response_3 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_3.uuid,
                                       used_in_clue_calculations: true
      @response_4 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_4.uuid,
                                       used_in_clue_calculations: false
      @response_5 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_1.uuid,
                                       exercise_uuid: @exercise_5.uuid,
                                       used_in_clue_calculations: false
      @response_6 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_1.uuid,
                                       used_in_clue_calculations: true
      @response_7 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_2.uuid,
                                       used_in_clue_calculations: true
      @response_8 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_3.uuid,
                                       used_in_clue_calculations: false
      @response_9 = FactoryGirl.create :response,
                                       is_correct: true,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_4.uuid,
                                       used_in_clue_calculations: false
      @response_10 = FactoryGirl.create :response,
                                       is_correct: false,
                                       student_uuid: @student_2.uuid,
                                       exercise_uuid: @exercise_5.uuid,
                                       used_in_clue_calculations: false

      @unprocessed_responses = [ @response_4, @response_5, @response_8, @response_9, @response_10 ]
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'marks the Responses as processed' do
      expect do
        subject.process
      end.to  not_change { Response.count               }
         .and not_change { StudentClueCalculation.count }
         .and not_change { TeacherClueCalculation.count }
         .and not_change { AlgorithmStudentClueCalculation.count }
         .and not_change { AlgorithmTeacherClueCalculation.count }
         .and not_change { StudentPeCalculation.count   }

      @unprocessed_responses.each do |response|
        expect(response.reload.used_in_clue_calculations).to eq true
      end
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

        # Will not updated due to no new responses
        calc_1 = FactoryGirl.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_1.book_container_uuid
        FactoryGirl.create :algorithm_student_clue_calculation, student_clue_calculation: calc_1

        # Will be updated
        calc_2 = FactoryGirl.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_2.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ]
        FactoryGirl.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: calc_2

        # Exclude @response_8 from the Student CLUe (but not the Teacher CLUe)
        assignment = FactoryGirl.create :assignment, student_uuid: @student_2.uuid,
                                                     due_at: Time.now.tomorrow
        FactoryGirl.create :assigned_exercise, uuid: @response_10.uuid,
                                               assignment_uuid: assignment.uuid
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'creates the StudentClueCalculation and TeacherClueCalculation records' +
         ' and marks the Responses as processed' do
        student_uuids = [ @student_1.uuid, @student_2.uuid ]
        book_container_uuids = [ @ep_1.book_container_uuid, @ep_2.book_container_uuid ]

        expect do
          subject.process
        end.to  not_change { Response.count                        }
           .and change     { StudentClueCalculation.count          }.by(3)
           .and change     { TeacherClueCalculation.count          }.by(1)
           .and not_change { AlgorithmStudentClueCalculation.count }
           .and change     { AlgorithmTeacherClueCalculation.count }.by(-1)
           .and not_change { StudentPeCalculation.count            }

        @unprocessed_responses.each do |response|
          expect(response.reload.used_in_clue_calculations).to eq true
        end
      end
    end
  end
end

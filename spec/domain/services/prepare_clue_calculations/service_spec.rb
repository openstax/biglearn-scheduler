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
    end
  end

  context 'with existing Ecosystems, Course, Students, Responses,
           Exercises, AssignedExercises and Assignments' do
    context 'with no Ecosystem updates' do
      before(:all) do
        DatabaseCleaner.start

        ecosystem = FactoryBot.create :ecosystem

        @course = FactoryBot.create :course, ecosystem_uuid: ecosystem.uuid

        @cc_1 = FactoryBot.create :course_container, course_uuid: @course.uuid,
                                                      student_uuids: []
        @cc_2 = FactoryBot.create :course_container, course_uuid: @course.uuid,
                                                      student_uuids: []

        @student_1 = FactoryBot.create :student, course_uuid: @course.uuid,
                                                  course_container_uuids: [ @cc_1.uuid ]
        @student_2 = FactoryBot.create :student, course_uuid: @course.uuid,
                                                  course_container_uuids: [ @cc_1.uuid ]

        @cc_1.update_attribute :student_uuids, [ @student_1.uuid, @student_2.uuid ]

        @exercise_1  = FactoryBot.create :exercise
        @exercise_2  = FactoryBot.create :exercise
        @exercise_3  = FactoryBot.create :exercise
        @exercise_4  = FactoryBot.create :exercise
        @exercise_5  = FactoryBot.create :exercise
        @exercise_6  = FactoryBot.create :exercise
        @exercise_7  = FactoryBot.create :exercise
        @exercise_8  = FactoryBot.create :exercise
        @exercise_9  = FactoryBot.create :exercise
        @exercise_10 = FactoryBot.create :exercise

        assignment_1 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_2 = FactoryBot.create :assignment, student_uuid: @student_1.uuid,
                                                       feedback_at: Time.current
        assignment_3 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_4 = FactoryBot.create :assignment, student_uuid: @student_1.uuid,
                                                       feedback_at: Time.current.tomorrow
        assignment_5 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_6 = FactoryBot.create :assignment, student_uuid: @student_2.uuid
        assignment_7 = FactoryBot.create :assignment, student_uuid: @student_2.uuid,
                                                       feedback_at: Time.current
        assignment_8 = FactoryBot.create :assignment, student_uuid: @student_2.uuid
        assignment_9 = FactoryBot.create :assignment, student_uuid: @student_2.uuid,
                                                       feedback_at: Time.current.tomorrow
        assignment_10 = FactoryBot.create :assignment, student_uuid: @student_2.uuid

        @response_1 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_1.uuid,
                                         is_used_in_clue_calculations: true
        @response_2 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_2.uuid,
                                         is_used_in_clue_calculations: true
        @response_3 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_3.uuid,
                                         is_used_in_clue_calculations: true
        @response_4 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_4.uuid,
                                         is_used_in_clue_calculations: true
        @response_5 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_5.uuid,
                                         is_used_in_clue_calculations: false
        @response_6 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_6.uuid,
                                         is_used_in_clue_calculations: false
        @response_7 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_7.uuid,
                                         is_used_in_clue_calculations: false
        @response_8 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_8.uuid,
                                         is_used_in_clue_calculations: false
        @response_9 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem.uuid,
                                         student_uuid: @student_2.uuid,
                                         exercise_uuid: @exercise_1.uuid,
                                         is_used_in_clue_calculations: true
        @response_10 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_2.uuid,
                                          is_used_in_clue_calculations: true
        @response_11 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_3.uuid,
                                          is_used_in_clue_calculations: true
        @response_12 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_4.uuid,
                                          is_used_in_clue_calculations: true
        @response_13 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_5.uuid,
                                          is_used_in_clue_calculations: false
        @response_14 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_6.uuid,
                                          is_used_in_clue_calculations: false
        @response_15 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_7.uuid,
                                          is_used_in_clue_calculations: false
        @response_16 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_8.uuid,
                                          is_used_in_clue_calculations: false

        @unprocessed_responses = [
          @response_5, @response_6, @response_7, @response_8,
          @response_13, @response_14, @response_15, @response_16
        ]

        [ @response_1, @response_2 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_1.uuid
        end
        [ @response_3, @response_4 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_2.uuid
        end
        [ @response_5, @response_6 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_3.uuid
        end
        [ @response_7, @response_8 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_4.uuid
        end
        [ @response_9, @response_10 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_6.uuid
        end
        [ @response_11, @response_12 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_7.uuid
        end
        [ @response_13, @response_14 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_8.uuid
        end
        [ @response_15, @response_16 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_9.uuid
        end

        @ep_1 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_1.uuid,
                                                                     @exercise_2.uuid ]

        @ep_2 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_3.uuid,
                                                                     @exercise_4.uuid ]
        @ep_3 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_5.uuid,
                                                                     @exercise_6.uuid ]
        @ep_4 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_7.uuid,
                                                                     @exercise_8.uuid ]
        @ep_5 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_9.uuid,
                                                                     @exercise_10.uuid ]

        # Not used for CLUes, so ignored
        FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem.uuid,
                                           book_container_uuid: @ep_1.book_container_uuid,
                                           use_for_clue: false,
                                           exercise_uuids: [
          @exercise_1.uuid, @exercise_2.uuid, @exercise_3.uuid, @exercise_4.uuid, @exercise_5.uuid,
          @exercise_6.uuid, @exercise_7.uuid, @exercise_8.uuid, @exercise_9.uuid, @exercise_10.uuid
        ]

        book_container_uuids_1 = [ SecureRandom.uuid, @ep_1.book_container_uuid ]
        book_container_uuids_2 = [ SecureRandom.uuid, @ep_2.book_container_uuid ]
        book_container_uuids_3 = [ SecureRandom.uuid, @ep_3.book_container_uuid ]
        book_container_uuids_4 = [ SecureRandom.uuid, @ep_4.book_container_uuid ]
        book_container_uuids_5 = [ SecureRandom.uuid, @ep_5.book_container_uuid ]

        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_1,
                                                book_container_uuids: book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_2,
                                                book_container_uuids: book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_3,
                                                book_container_uuids: book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_4,
                                                book_container_uuids: book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_5,
                                                book_container_uuids: book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_6,
                                                book_container_uuids: book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_7,
                                                book_container_uuids: book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_8,
                                                book_container_uuids: book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_9,
                                                book_container_uuids: book_container_uuids_5
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem.uuid,
                                                exercise: @exercise_10,
                                                book_container_uuids: book_container_uuids_5

        # Will not be updated (no activity)
        @scc_1 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_1.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_1

        # Will be updated (recalculate_at)
        @scc_2 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_2.book_container_uuid,
                                    recalculate_at: assignment_2.feedback_at
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_2

        # Will be updated (new responses)
        @scc_3 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_3.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_3

        # Will be updated (anti-cheating sets recalculate_at)
        @scc_4 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_4.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_4

        # Will not be updated (no responses)
        @scc_5 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_5.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_5

        # Will not be updated (no activity)
        @tcc_1 = FactoryBot.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_1.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ]
        FactoryBot.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: @tcc_1

        # Will be updated (recalculate_at)
        @tcc_2 = FactoryBot.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_2.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ],
                                    recalculate_at: assignment_2.feedback_at
        FactoryBot.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: @tcc_2

        # Will be updated (new responses)
        @tcc_3 = FactoryBot.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_3.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ]
        FactoryBot.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: @tcc_3
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'creates the StudentClueCalculation and TeacherClueCalculation records' +
         ' and marks the Responses as processed' do
        expect do
          subject.process
        end.to  not_change { Response.count                        }
           .and change     { StudentClueCalculation.count          }.by(2)
           .and change     { TeacherClueCalculation.count          }.by(1)
           .and change     { AlgorithmStudentClueCalculation.count }.by(-3)
           .and change     { AlgorithmTeacherClueCalculation.count }.by(-2)
           .and not_change { @scc_1.reload.uuid                    }
           .and change     { @scc_2.reload.uuid                    }
           .and change     { @scc_3.reload.uuid                    }
           .and change     { @scc_4.reload.uuid                    }
           .and not_change { @scc_5.reload.uuid                    }
           .and not_change { @tcc_1.reload.uuid                    }
           .and change     { @tcc_2.reload.uuid                    }
           .and change     { @tcc_3.reload.uuid                    }

        @unprocessed_responses.each do |response|
          expect(response.reload.is_used_in_clue_calculations).to eq true
        end

        expect(@scc_2.exercise_uuids).to match_array [ @exercise_3, @exercise_4 ].map(&:uuid)
        expect(@scc_2.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_3, @response_4 ].map(&:uuid)
        )
        expect(@scc_2.recalculate_at).to be_nil

        expect(@scc_3.exercise_uuids).to match_array [ @exercise_5, @exercise_6 ].map(&:uuid)
        expect(@scc_3.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_5, @response_6 ].map(&:uuid)
        )
        expect(@scc_3.recalculate_at).to be_nil

        expect(@scc_4.exercise_uuids).to match_array [ @exercise_7, @exercise_8 ].map(&:uuid)
        expect(@scc_4.responses).to be_empty
        expect(@scc_4.recalculate_at).not_to be_nil

        new_sccs = StudentClueCalculation.order(:created_at).last(2)
        new_sccs.each do |new_scc|
          expect(new_scc.student_uuid).to eq @student_2.uuid
          expect(new_scc.book_container_uuid).to(
            be_in [ @ep_3.book_container_uuid, @ep_4.book_container_uuid ]
          )

          if new_scc.book_container_uuid == @ep_3.book_container_uuid
            expect(new_scc.responses.map { |response| response['response_uuid'] }).to(
              match_array [ @response_13, @response_14 ].map(&:uuid)
            )
          else
            expect(new_scc.responses).to be_empty
          end
        end

        expect(@tcc_2.exercise_uuids).to match_array [ @exercise_3, @exercise_4 ].map(&:uuid)
        expect(@tcc_2.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_3, @response_4, @response_11, @response_12 ].map(&:uuid)
        )
        expect(@tcc_2.recalculate_at).to be_nil

        expect(@tcc_3.exercise_uuids).to match_array [ @exercise_5, @exercise_6 ].map(&:uuid)
        expect(@tcc_3.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_5, @response_6, @response_13, @response_14 ].map(&:uuid)
        )
        expect(@tcc_3.recalculate_at).to be_nil

        new_tcc = TeacherClueCalculation.order(:created_at).last
        expect(new_tcc.exercise_uuids).to match_array [ @exercise_7, @exercise_8 ].map(&:uuid)
        expect(new_tcc.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_7, @response_8, @response_15, @response_16 ].map(&:uuid)
        )
      end
    end

    context 'after an Ecosystem update' do
      before(:all) do
        DatabaseCleaner.start

        ecosystem_1 = FactoryBot.create :ecosystem
        ecosystem_2 = FactoryBot.create :ecosystem

        @course = FactoryBot.create :course, ecosystem_uuid: ecosystem_2.uuid

        @cc_1 = FactoryBot.create :course_container, course_uuid: @course.uuid,
                                                      student_uuids: []
        @cc_2 = FactoryBot.create :course_container, course_uuid: @course.uuid,
                                                      student_uuids: []

        @student_1 = FactoryBot.create :student, course_uuid: @course.uuid,
                                                  course_container_uuids: [ @cc_1.uuid ]
        @student_2 = FactoryBot.create :student, course_uuid: @course.uuid,
                                                  course_container_uuids: [ @cc_1.uuid ]

        @cc_1.update_attribute :student_uuids, [ @student_1.uuid, @student_2.uuid ]

        @exercise_1  = FactoryBot.create :exercise
        @exercise_2  = FactoryBot.create :exercise
        @exercise_3  = FactoryBot.create :exercise
        @exercise_4  = FactoryBot.create :exercise
        @exercise_5  = FactoryBot.create :exercise
        @exercise_6  = FactoryBot.create :exercise
        @exercise_7  = FactoryBot.create :exercise
        @exercise_8  = FactoryBot.create :exercise
        @exercise_9  = FactoryBot.create :exercise
        @exercise_10 = FactoryBot.create :exercise
        @exercise_11  = FactoryBot.create :exercise
        @exercise_12  = FactoryBot.create :exercise
        @exercise_13  = FactoryBot.create :exercise
        @exercise_14  = FactoryBot.create :exercise
        @exercise_15  = FactoryBot.create :exercise

        assignment_1 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_2 = FactoryBot.create :assignment, student_uuid: @student_1.uuid,
                                                       feedback_at: Time.current
        assignment_3 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_4 = FactoryBot.create :assignment, student_uuid: @student_1.uuid,
                                                       feedback_at: Time.current.tomorrow
        assignment_5 = FactoryBot.create :assignment, student_uuid: @student_1.uuid
        assignment_6 = FactoryBot.create :assignment, student_uuid: @student_2.uuid
        assignment_7 = FactoryBot.create :assignment, student_uuid: @student_2.uuid,
                                                       feedback_at: Time.current
        assignment_8 = FactoryBot.create :assignment, student_uuid: @student_2.uuid
        assignment_9 = FactoryBot.create :assignment, student_uuid: @student_2.uuid,
                                                       feedback_at: Time.current.tomorrow
        assignment_10 = FactoryBot.create :assignment, student_uuid: @student_2.uuid

        @response_1 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_1.uuid,
                                         is_used_in_clue_calculations: true
        @response_2 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem_2.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_12.uuid,
                                         is_used_in_clue_calculations: true
        @response_3 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_3.uuid,
                                         is_used_in_clue_calculations: true
        @response_4 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem_2.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_14.uuid,
                                         is_used_in_clue_calculations: true
        @response_5 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_5.uuid,
                                         is_used_in_clue_calculations: false
        @response_6 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem_2.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_6.uuid,
                                         is_used_in_clue_calculations: false
        @response_7 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_7.uuid,
                                         is_used_in_clue_calculations: false
        @response_8 = FactoryBot.create :response,
                                         is_correct: false,
                                         ecosystem_uuid: ecosystem_2.uuid,
                                         student_uuid: @student_1.uuid,
                                         exercise_uuid: @exercise_8.uuid,
                                         is_used_in_clue_calculations: false
        @response_9 = FactoryBot.create :response,
                                         is_correct: true,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         student_uuid: @student_2.uuid,
                                         exercise_uuid: @exercise_1.uuid,
                                         is_used_in_clue_calculations: true
        @response_10 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem_2.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_12.uuid,
                                          is_used_in_clue_calculations: true
        @response_11 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem_1.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_3.uuid,
                                          is_used_in_clue_calculations: true
        @response_12 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem_2.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_14.uuid,
                                          is_used_in_clue_calculations: true
        @response_13 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem_1.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_5.uuid,
                                          is_used_in_clue_calculations: false
        @response_14 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem_2.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_6.uuid,
                                          is_used_in_clue_calculations: false
        @response_15 = FactoryBot.create :response,
                                          is_correct: true,
                                          ecosystem_uuid: ecosystem_1.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_7.uuid,
                                          is_used_in_clue_calculations: false
        @response_16 = FactoryBot.create :response,
                                          is_correct: false,
                                          ecosystem_uuid: ecosystem_2.uuid,
                                          student_uuid: @student_2.uuid,
                                          exercise_uuid: @exercise_8.uuid,
                                          is_used_in_clue_calculations: false

        @unprocessed_responses = [
          @response_5, @response_6, @response_7, @response_8,
          @response_13, @response_14, @response_15, @response_16
        ]

        [ @response_1, @response_2 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_1.uuid
        end
        [ @response_3, @response_4 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_2.uuid
        end
        [ @response_5, @response_6 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_3.uuid
        end
        [ @response_7, @response_8 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_4.uuid
        end
        [ @response_9, @response_10 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_6.uuid
        end
        [ @response_11, @response_12 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_7.uuid
        end
        [ @response_13, @response_14 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_8.uuid
        end
        [ @response_15, @response_16 ].each do |response|
          FactoryBot.create :assigned_exercise, uuid: response.trial_uuid,
                                                 assignment_uuid: assignment_9.uuid
        end

        # Old ecosystem
        old_ep_1 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_1.uuid,
                                                      use_for_clue: true,
                                                      exercise_uuids: [ @exercise_1.uuid,
                                                                        @exercise_2.uuid ]

        old_ep_2 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_1.uuid,
                                                      use_for_clue: true,
                                                      exercise_uuids: [ @exercise_3.uuid,
                                                                        @exercise_4.uuid ]
        old_ep_3 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_1.uuid,
                                                      use_for_clue: true,
                                                      exercise_uuids: [ @exercise_5.uuid,
                                                                        @exercise_6.uuid ]
        old_ep_4 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_1.uuid,
                                                      use_for_clue: true,
                                                      exercise_uuids: [ @exercise_7.uuid,
                                                                        @exercise_8.uuid ]
        old_ep_5 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_1.uuid,
                                                      use_for_clue: true,
                                                      exercise_uuids: [ @exercise_9.uuid,
                                                                        @exercise_10.uuid ]

        # New ecosystem
        @ep_1 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_2.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_11.uuid,
                                                                     @exercise_12.uuid ]

        @ep_2 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_2.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_13.uuid,
                                                                     @exercise_14.uuid ]
        @ep_3 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_2.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_15.uuid,
                                                                     @exercise_6.uuid ]
        @ep_4 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_2.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_7.uuid,
                                                                     @exercise_8.uuid ]
        @ep_5 = FactoryBot.create :exercise_pool, ecosystem_uuid: ecosystem_2.uuid,
                                                   use_for_clue: true,
                                                   exercise_uuids: [ @exercise_9.uuid,
                                                                     @exercise_10.uuid ]

        # Not used for CLUes, so ignored
        unused_ep_1 = FactoryBot.create :exercise_pool,
                                         ecosystem_uuid: ecosystem_1.uuid,
                                         use_for_clue: false,
                                         exercise_uuids: [
          @exercise_1.uuid, @exercise_2.uuid, @exercise_3.uuid, @exercise_4.uuid, @exercise_5.uuid,
          @exercise_6.uuid, @exercise_7.uuid, @exercise_8.uuid, @exercise_9.uuid, @exercise_10.uuid
        ]
        unused_ep_2 = FactoryBot.create :exercise_pool,
                                         ecosystem_uuid: ecosystem_2.uuid,
                                         use_for_clue: false,
                                         exercise_uuids: [
          @exercise_11.uuid, @exercise_12.uuid, @exercise_13.uuid, @exercise_14.uuid,
          @exercise_15.uuid, @exercise_6.uuid, @exercise_7.uuid,
          @exercise_8.uuid, @exercise_9.uuid, @exercise_10.uuid
        ]

        # Mappings
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: old_ep_1.book_container_uuid,
                           to_book_container_uuid: @ep_1.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: old_ep_2.book_container_uuid,
                           to_book_container_uuid: @ep_2.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: old_ep_3.book_container_uuid,
                           to_book_container_uuid: @ep_3.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: old_ep_4.book_container_uuid,
                           to_book_container_uuid: @ep_4.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: old_ep_5.book_container_uuid,
                           to_book_container_uuid: @ep_5.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_1.uuid,
                           to_ecosystem_uuid: ecosystem_2.uuid,
                           from_book_container_uuid: unused_ep_1.book_container_uuid,
                           to_book_container_uuid: unused_ep_2.book_container_uuid

        # Reverse mappings
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: @ep_1.book_container_uuid,
                           to_book_container_uuid: old_ep_1.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: @ep_2.book_container_uuid,
                           to_book_container_uuid: old_ep_2.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: @ep_3.book_container_uuid,
                           to_book_container_uuid: old_ep_3.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: @ep_4.book_container_uuid,
                           to_book_container_uuid: old_ep_4.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: @ep_5.book_container_uuid,
                           to_book_container_uuid: old_ep_5.book_container_uuid
        FactoryBot.create :book_container_mapping,
                           from_ecosystem_uuid: ecosystem_2.uuid,
                           to_ecosystem_uuid: ecosystem_1.uuid,
                           from_book_container_uuid: unused_ep_2.book_container_uuid,
                           to_book_container_uuid: unused_ep_1.book_container_uuid

        old_book_container_uuids_1 = [ SecureRandom.uuid, old_ep_1.book_container_uuid ]
        old_book_container_uuids_2 = [ SecureRandom.uuid, old_ep_2.book_container_uuid ]
        old_book_container_uuids_3 = [ SecureRandom.uuid, old_ep_3.book_container_uuid ]
        old_book_container_uuids_4 = [ SecureRandom.uuid, old_ep_4.book_container_uuid ]
        old_book_container_uuids_5 = [ SecureRandom.uuid, old_ep_5.book_container_uuid ]
        book_container_uuids_1 = [ SecureRandom.uuid, @ep_1.book_container_uuid ]
        book_container_uuids_2 = [ SecureRandom.uuid, @ep_2.book_container_uuid ]
        book_container_uuids_3 = [ SecureRandom.uuid, @ep_3.book_container_uuid ]
        book_container_uuids_4 = [ SecureRandom.uuid, @ep_4.book_container_uuid ]
        book_container_uuids_5 = [ SecureRandom.uuid, @ep_5.book_container_uuid ]

        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_1,
                                                book_container_uuids: old_book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_2,
                                                book_container_uuids: old_book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_3,
                                                book_container_uuids: old_book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_4,
                                                book_container_uuids: old_book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_5,
                                                book_container_uuids: old_book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_6,
                                                book_container_uuids: old_book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_7,
                                                book_container_uuids: old_book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_8,
                                                book_container_uuids: old_book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_9,
                                                book_container_uuids: old_book_container_uuids_5
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_1.uuid,
                                                exercise: @exercise_10,
                                                book_container_uuids: old_book_container_uuids_5
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_11,
                                                book_container_uuids: book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_12,
                                                book_container_uuids: book_container_uuids_1
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_13,
                                                book_container_uuids: book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_14,
                                                book_container_uuids: book_container_uuids_2
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_15,
                                                book_container_uuids: book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_6,
                                                book_container_uuids: book_container_uuids_3
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_7,
                                                book_container_uuids: book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_8,
                                                book_container_uuids: book_container_uuids_4
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_9,
                                                book_container_uuids: book_container_uuids_5
        FactoryBot.create :ecosystem_exercise, ecosystem_uuid: ecosystem_2.uuid,
                                                exercise: @exercise_10,
                                                book_container_uuids: book_container_uuids_5

        # Will not be updated (no activity)
        @scc_1 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_1.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_1

        # Will be updated (recalculate_at)
        @scc_2 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_2.book_container_uuid,
                                    recalculate_at: assignment_2.feedback_at
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_2

        # Will be updated (new responses)
        @scc_3 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_3.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_3

        # Will be updated (anti-cheating sets recalculate_at)
        @scc_4 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_4.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_4

        # Will not be updated (no responses)
        @scc_5 = FactoryBot.create :student_clue_calculation,
                                    student_uuid: @student_1.uuid,
                                    book_container_uuid: @ep_5.book_container_uuid
        FactoryBot.create :algorithm_student_clue_calculation, student_clue_calculation: @scc_5

        # Will not be updated (no activity)
        @tcc_1 = FactoryBot.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_1.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ]
        FactoryBot.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: @tcc_1

        # Will be updated (new responses)
        @tcc_2 = FactoryBot.create :teacher_clue_calculation,
                                    book_container_uuid: @ep_3.book_container_uuid,
                                    course_container_uuid: @cc_1.uuid,
                                    student_uuids: [ @student_1.uuid, @student_2.uuid ]
        FactoryBot.create :algorithm_teacher_clue_calculation, teacher_clue_calculation: @tcc_2
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'creates the StudentClueCalculation and TeacherClueCalculation records' +
         ' and marks the Responses as processed' do
        expect do
          subject.process
        end.to  not_change { Response.count                        }
           .and change     { StudentClueCalculation.count          }.by(2)
           .and change     { TeacherClueCalculation.count          }.by(1)
           .and change     { AlgorithmStudentClueCalculation.count }.by(-3)
           .and change     { AlgorithmTeacherClueCalculation.count }.by(-1)
           .and not_change { @scc_1.reload.uuid                    }
           .and change     { @scc_2.reload.uuid                    }
           .and change     { @scc_3.reload.uuid                    }
           .and change     { @scc_4.reload.uuid                    }
           .and not_change { @scc_5.reload.uuid                    }
           .and not_change { @tcc_1.reload.uuid                    }
           .and change     { @tcc_2.reload.uuid                    }

        @unprocessed_responses.each do |response|
          expect(response.reload.is_used_in_clue_calculations).to eq true
        end

        expect(@scc_2.exercise_uuids).to(
          match_array [ @exercise_3, @exercise_4, @exercise_13, @exercise_14 ].map(&:uuid)
        )
        expect(@scc_2.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_3, @response_4 ].map(&:uuid)
        )
        expect(@scc_2.recalculate_at).to be_nil

        expect(@scc_3.exercise_uuids).to(
          match_array [ @exercise_5, @exercise_6, @exercise_15 ].map(&:uuid)
        )
        expect(@scc_3.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_5, @response_6 ].map(&:uuid)
        )
        expect(@scc_3.recalculate_at).to be_nil

        expect(@scc_4.exercise_uuids).to match_array [ @exercise_7, @exercise_8 ].map(&:uuid)
        expect(@scc_4.responses).to be_empty
        expect(@scc_4.recalculate_at).not_to be_nil

        new_sccs = StudentClueCalculation.order(:created_at).last(2)
        new_sccs.each do |new_scc|
          expect(new_scc.student_uuid).to eq @student_2.uuid
          expect(new_scc.book_container_uuid).to(
            be_in [ @ep_3.book_container_uuid, @ep_4.book_container_uuid ]
          )

          if new_scc.book_container_uuid == @ep_3.book_container_uuid
            expect(new_scc.responses.map { |response| response['response_uuid'] }).to(
              match_array [ @response_13, @response_14 ].map(&:uuid)
            )
          else
            expect(new_scc.responses).to be_empty
          end
        end

        expect(@tcc_2.exercise_uuids).to(
          match_array [ @exercise_5, @exercise_6, @exercise_15 ].map(&:uuid)
        )
        expect(@tcc_2.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_5, @response_6, @response_13, @response_14 ].map(&:uuid)
        )

        new_tcc = TeacherClueCalculation.order(:created_at).last
        expect(new_tcc.exercise_uuids).to match_array [ @exercise_7, @exercise_8 ].map(&:uuid)
        expect(new_tcc.responses.map { |response| response['response_uuid'] }).to(
          match_array [ @response_7, @response_8, @response_15, @response_16 ].map(&:uuid)
        )
      end
    end
  end
end

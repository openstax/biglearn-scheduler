require 'rails_helper'

RSpec.describe Services::UpdateAssignmentExercises::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments' do
    it 'does not update any SPEs or PEs' do
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes).with([])
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes).with([])

      expect { subject.process }.to  not_change { Assignment.count    }
                                .and not_change { AssignmentSpe.count }
                                .and not_change { AssignmentPe.count  }
    end
  end

  context 'with existing Course, ExercisePools, Exercises, BookContainerMappings and Assignments' do
    before(:all) do
      DatabaseCleaner.start

      ecosystem_uuid_1 = SecureRandom.uuid
      ecosystem_uuid_2 = SecureRandom.uuid

      @reading_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_1,
                         to_ecosystem_uuid: ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_new.book_container_uuid
      @reading_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_1,
                         to_ecosystem_uuid: ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_new.book_container_uuid
      @reading_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )

      @homework_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      @homework_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      @homework_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 4,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      @homework_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      @homework_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      @homework_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      @homework_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      practice_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_old.exercise_uuids + @homework_pool_1_old.exercise_uuids,
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      practice_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_new.exercise_uuids + @homework_pool_1_new.exercise_uuids,
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      practice_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_old.exercise_uuids + @homework_pool_2_old.exercise_uuids,
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      practice_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_new.exercise_uuids + @homework_pool_2_new.exercise_uuids,
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      practice_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_3_new.exercise_uuids + @homework_pool_3_new.exercise_uuids,
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      practice_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_4_new.exercise_uuids + @homework_pool_4_new.exercise_uuids,
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      practice_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_5_new.exercise_uuids + @homework_pool_5_new.exercise_uuids,
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      exercise_uuids = [
        practice_pool_1_new,
        practice_pool_2_new,
        practice_pool_3_new,
        practice_pool_4_new,
        practice_pool_5_new
      ].flat_map(&:exercise_uuids)
      exercise_uuids.each { |exercise_uuid| FactoryGirl.create :exercise, uuid: exercise_uuid }

      course = FactoryGirl.create :course
      course_uuid = course.uuid
      student_uuid = SecureRandom.uuid

      # 0 SPEs, 0 PEs requested
      @reading_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_uuid_1,
        assigned_exercise_uuids: @reading_pool_1_old.exercise_uuids.sample(5) +
                                 @reading_pool_2_old.exercise_uuids.sample(5),
        assigned_book_container_uuids: [
          @reading_pool_1_old.book_container_uuid, @reading_pool_2_old.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 0,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 0,
        pes_are_assigned: false
      )

      # 1 SPEs, 1 PEs requested; 1 SPE filled as PE since no 2-ago reading
      @reading_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_uuid_2,
        assigned_exercise_uuids: @reading_pool_3_new.exercise_uuids.sample(5) +
                                 @reading_pool_4_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [
          @reading_pool_3_new.book_container_uuid, @reading_pool_4_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 1,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      # 2 SPEs, 2 PEs requested; 1 SPE from reading 1, 1 SPE filled as PE since no 4-ago reading
      @reading_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_uuid_2,
        assigned_exercise_uuids: @reading_pool_4_new.exercise_uuids.sample(5) +
                                 @reading_pool_5_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [
          @reading_pool_4_new.book_container_uuid, @reading_pool_5_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 2,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 2,
        pes_are_assigned: false
      )

      # These homeworks are taking all available exercises, so no PEs are possible
      # 0 SPEs, 0 PEs requested
      @homework_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_uuid_1,
        assigned_exercise_uuids: @homework_pool_1_old.exercise_uuids +
                                 @homework_pool_2_old.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_1_old.book_container_uuid, @homework_pool_2_old.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 0,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 0,
        pes_are_assigned: false
      )

      # 1 SPE, 1 PE requested; No exercises available to fill either
      @homework_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_uuid_2,
        assigned_exercise_uuids: @homework_pool_3_new.exercise_uuids +
                                 @homework_pool_4_new.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_3_new.book_container_uuid, @homework_pool_4_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 1,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      # 2 SPEs, 1 PE requested; Only 1 SPE can be filled from homework 1
      @homework_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course_uuid,
        student_uuid: student_uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_uuid_2,
        assigned_exercise_uuids: @homework_pool_4_new.exercise_uuids +
                                 @homework_pool_5_new.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_4_new.book_container_uuid, @homework_pool_5_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 2,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:expected_spe_requests) do
      [
        {
          assignment_uuid: @reading_2.uuid,
          exercise_uuids: [
            be_in(@reading_pool_3_new.exercise_uuids + @reading_pool_4_new.exercise_uuids)
          ],
          algorithm_name: 'local_query_instructor_driven'
        },
        {
          assignment_uuid: @reading_3.uuid,
          exercise_uuids: match_array([
            be_in(@reading_pool_1_new.exercise_uuids + @reading_pool_2_new.exercise_uuids),
            be_in(@reading_pool_4_new.exercise_uuids + @reading_pool_5_new.exercise_uuids)
          ]),
          algorithm_name: 'local_query_instructor_driven'
        },
        {
          assignment_uuid: @homework_2.uuid,
          exercise_uuids: [],
          algorithm_name: 'local_query_instructor_driven'
        },
        {
          assignment_uuid: @homework_3.uuid,
          exercise_uuids: [
            be_in(@homework_pool_1_new.exercise_uuids + @homework_pool_2_new.exercise_uuids)
          ],
          algorithm_name: 'local_query_instructor_driven'
        },
        {
          assignment_uuid: @reading_2.uuid,
          exercise_uuids: [
            be_in(@reading_pool_3_new.exercise_uuids + @reading_pool_4_new.exercise_uuids)
          ],
          algorithm_name: 'local_query_student_driven'
        },
        {
          assignment_uuid: @reading_3.uuid,
          exercise_uuids: match_array([
            be_in(@reading_pool_1_new.exercise_uuids + @reading_pool_2_new.exercise_uuids),
            be_in(@reading_pool_4_new.exercise_uuids + @reading_pool_5_new.exercise_uuids)
          ]),
          algorithm_name: 'local_query_student_driven'
        },
        {
          assignment_uuid: @homework_2.uuid,
          exercise_uuids: [],
          algorithm_name: 'local_query_student_driven'
        },
        {
          assignment_uuid: @homework_3.uuid,
          exercise_uuids: [
            be_in(@homework_pool_1_new.exercise_uuids + @homework_pool_2_new.exercise_uuids)
          ],
          algorithm_name: 'local_query_student_driven'
        }
      ]
    end

    let(:expected_pe_requests) do
      [
        {
          assignment_uuid: @reading_2.uuid,
          exercise_uuids: [
            be_in(@reading_pool_3_new.exercise_uuids + @reading_pool_4_new.exercise_uuids)
          ]
        },
        {
          assignment_uuid: @reading_3.uuid,
          exercise_uuids: match_array([
            be_in(@reading_pool_4_new.exercise_uuids + @reading_pool_5_new.exercise_uuids)
          ] * 2)
        },
        {
          assignment_uuid: @homework_2.uuid,
          exercise_uuids: []
        },
        {
          assignment_uuid: @homework_3.uuid,
          exercise_uuids: []
        }
      ]
    end

    it 'assigns the correct numbers of SPEs and PEs from the correct pools' do
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes) do |requests|
        expect(requests).to match_array expected_spe_requests
      end
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes) do |requests|
        expect(requests).to match_array expected_pe_requests
      end

      expect { subject.process }.to  not_change { Assignment.count    }
                                .and change     { AssignmentSpe.count }.by(8)
                                .and change     { AssignmentPe.count  }.by(3)
    end

    context 'with some SPEs and PEs already assigned' do
      before(:all) do
        DatabaseCleaner.start

        reading_3_assigned_spe_pool = @reading_pool_1_new
        reading_3_assigned_spe_uuid = reading_3_assigned_spe_pool.exercise_uuids.sample
        [ :instructor_driven, :student_driven ].each do |history_type|
          FactoryGirl.create :assignment_spe,
                             student_uuid: @reading_3.student_uuid,
                             assignment_uuid: @reading_3.uuid,
                             history_type: history_type,
                             book_container_uuid: reading_3_assigned_spe_pool.book_container_uuid,
                             exercise_uuid: reading_3_assigned_spe_uuid,
                             k_ago: 2
        end

        reading_3_assigned_pe_pool = [@reading_pool_4_new, @reading_pool_5_new].sample
        reading_3_available_pe_uuids = reading_3_assigned_pe_pool.exercise_uuids -
                                       @reading_3.assigned_exercise_uuids
        reading_3_assigned_pe_uuid = reading_3_available_pe_uuids.sample
        FactoryGirl.create :assignment_pe,
                           student_uuid: @reading_3.student_uuid,
                           assignment_uuid: @reading_3.uuid,
                           book_container_uuid: reading_3_assigned_pe_pool.book_container_uuid,
                           exercise_uuid: reading_3_assigned_pe_uuid

        homework_3_assigned_spe_pool = @homework_pool_1_new
        homework_3_assigned_spe_uuid = homework_3_assigned_spe_pool.exercise_uuids.sample
        [ :instructor_driven, :student_driven ].each do |history_type|
          FactoryGirl.create :assignment_spe,
                             student_uuid: @homework_3.student_uuid,
                             assignment_uuid: @homework_3.uuid,
                             history_type: history_type,
                             book_container_uuid: homework_3_assigned_spe_pool.book_container_uuid,
                             exercise_uuid: homework_3_assigned_spe_uuid,
                             k_ago: 2
        end
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'assigns only the missing SPEs and PEs from the correct pools' do
        expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes) do |requests|
          expect(requests).to match_array expected_spe_requests
        end
        expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes) do |requests|
          expect(requests).to match_array expected_pe_requests
        end

        expect { subject.process }.to  not_change { Assignment.count    }
                                  .and change     { AssignmentSpe.count }.by(4)
                                  .and change     { AssignmentPe.count  }.by(2)
      end
    end
  end
end

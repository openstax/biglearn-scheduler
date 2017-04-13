require 'rails_helper'

RSpec.describe Services::PrepareAssignmentExerciseCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments' do
    it 'does not create any SPE or PE calculations' do
      expect { subject.process }.to  not_change { AssignmentSpeCalculation.count          }
                                .and not_change { AssignmentSpeCalculationExercise.count  }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                .and not_change { AssignmentPeCalculation.count           }
                                .and not_change { AssignmentPeCalculationExercise.count   }
                                .and not_change { AlgorithmAssignmentPeCalculation.count  }
    end
  end

  context 'with existing Course, ExercisePools, Exercises,' +
          ' BookContainerMappings, Assignments and AssignedExercises' do
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
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_2,
                         to_ecosystem_uuid: ecosystem_uuid_1,
                         from_book_container_uuid: @reading_pool_1_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_old.book_container_uuid
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
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_2,
                         to_ecosystem_uuid: ecosystem_uuid_1,
                         from_book_container_uuid: @reading_pool_2_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_old.book_container_uuid
      @reading_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_1,
                         to_ecosystem_uuid: ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_3_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_3_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_2,
                         to_ecosystem_uuid: ecosystem_uuid_1,
                         from_book_container_uuid: @reading_pool_3_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_3_old.book_container_uuid
      @reading_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_1,
                         to_ecosystem_uuid: ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_4_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_4_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_2,
                         to_ecosystem_uuid: ecosystem_uuid_1,
                         from_book_container_uuid: @reading_pool_4_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_4_old.book_container_uuid
      @reading_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_1,
                         to_ecosystem_uuid: ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_5_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_5_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_uuid_2,
                         to_ecosystem_uuid: ecosystem_uuid_1,
                         from_book_container_uuid: @reading_pool_5_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_5_old.book_container_uuid

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
      @homework_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_old.book_container_uuid
      )
      @homework_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      @homework_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_old.book_container_uuid
      )
      @homework_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      @homework_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_5_old.book_container_uuid
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
      # 2 SPEs, 1 PE requested; No exercises available to fill either
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
        goal_num_tutor_assigned_spes: 2,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
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

    let(:expected_assignment_pe_calculations) do
      [
        {
          assignment_uuid: @reading_2.uuid,
          book_container_uuid: @reading_pool_3_new.book_container_uuid,
          exercise_uuids: @reading_pool_3_new.exercise_uuids - @reading_2.assigned_exercise_uuids,
          exercise_count: 1
        },
        {
          assignment_uuid: @reading_3.uuid,
          book_container_uuid: @reading_pool_4_new.book_container_uuid,
          exercise_uuids: @reading_pool_4_new.exercise_uuids - @reading_3.assigned_exercise_uuids,
          exercise_count: 1
        },
        {
          assignment_uuid: @reading_3.uuid,
          book_container_uuid: @reading_pool_5_new.book_container_uuid,
          exercise_uuids: @reading_pool_5_new.exercise_uuids - @reading_3.assigned_exercise_uuids,
          exercise_count: 1
        },
        {
          assignment_uuid: @homework_1.uuid,
          book_container_uuid: @homework_pool_1_old.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        },
        {
          assignment_uuid: @homework_1.uuid,
          book_container_uuid: @homework_pool_2_old.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        },
        {
          assignment_uuid: @homework_2.uuid,
          book_container_uuid: @homework_pool_3_new.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        },
        {
          assignment_uuid: @homework_2.uuid,
          book_container_uuid: @homework_pool_4_new.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        },
        {
          assignment_uuid: @homework_3.uuid,
          book_container_uuid: @homework_pool_4_new.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        },
        {
          assignment_uuid: @homework_3.uuid,
          book_container_uuid: @homework_pool_5_new.book_container_uuid,
          exercise_uuids: [],
          exercise_count: 0
        }
      ]
    end

    let(:indexed_assignment_pe_calculations) do
      expected_assignment_pe_calculations.index_by do |calc|
        [ calc[:assignment_uuid], calc[:book_container_uuid] ]
      end
    end

    let(:indexed_assignment_spe_calculations) do
      expected_assignment_spe_calculations.index_by do |calc|
        [ calc[:assignment_uuid], calc[:book_container_uuid], calc[:history_type], calc[:k_ago] ]
      end
    end

    let(:ordered_assignment_uuids) { ordered_assignments.map(&:uuid) }

    let(:assigned_exercises_by_assignment_uuid) do
      AssignedExercise.where(
        assignment_uuid: ordered_assignment_uuids,
        is_spe: false,
        is_pe: false
      ).group_by(&:assignment_uuid)
    end

    let!(:ordered_responses) do
      ordered_assignment_uuids.flat_map do |assignment_uuid|
        assigned_exercises = assigned_exercises_by_assignment_uuid[assignment_uuid]

        assigned_exercises.map do |assigned_exercise|
          FactoryGirl.create :response, uuid: assigned_exercise.uuid
        end
      end
    end

    context 'with assignments completed in the expected order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ]
      end

      let(:expected_assignment_spe_calculations) do
        [
          {
            assignment_uuid: @reading_2.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_3_new.exercise_uuids +
                            @reading_pool_4_new.exercise_uuids -
                            @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_2.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_3_new.exercise_uuids +
                            @reading_pool_4_new.exercise_uuids -
                            @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: @reading_pool_1_new.book_container_uuid,
            exercise_uuids: @reading_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_4_new.exercise_uuids +
                            @reading_pool_5_new.exercise_uuids -
                            @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: @reading_pool_1_new.book_container_uuid,
            exercise_uuids: @reading_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_4_new.exercise_uuids +
                            @reading_pool_5_new.exercise_uuids -
                            @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_2.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_2.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: @homework_pool_1_new.book_container_uuid,
            exercise_uuids: @homework_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: @homework_pool_1_new.book_container_uuid,
            exercise_uuids: @homework_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          }
        ]
      end

      it 'creates the correct numbers of SPE and PE calculations with the correct pools' do
        expected_num_spes = expected_assignment_spe_calculations
                              .map { |calc| calc[:exercise_uuids].size }
                              .reduce(0, :+)
        expected_num_pes = expected_assignment_pe_calculations
                             .map { |calc| calc[:exercise_uuids].size }
                             .reduce(0, :+)
        expect { subject.process }.to  change { AssignmentSpeCalculation.count         }
                                                .by(expected_assignment_spe_calculations.size)
                                  .and change { AssignmentSpeCalculationExercise.count }
                                                .by(expected_num_spes)
                                  .and change { AssignmentPeCalculation.count          }
                                                .by(expected_assignment_pe_calculations.size)
                                  .and change { AssignmentPeCalculationExercise.count  }
                                                .by(expected_num_pes)

        AssignmentSpeCalculation.all.each do |calc|
          index = [calc.assignment_uuid, calc.book_container_uuid, calc.history_type, calc.k_ago]
          expected_calculation = indexed_assignment_spe_calculations.fetch index
          expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
          expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
        end

        AssignmentPeCalculation.all.each do |calc|
          index = [calc.assignment_uuid, calc.book_container_uuid]
          expected_calculation = indexed_assignment_pe_calculations.fetch index
          expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
          expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
        end
      end

      context 'with some pre-existing calculations' do
        before(:all) do
          DatabaseCleaner.start

          reading_3_assigned_pe_pool = [@reading_pool_4_new, @reading_pool_5_new].sample
          reading_3_available_pe_uuids = reading_3_assigned_pe_pool.exercise_uuids -
                                         @reading_3.assigned_exercise_uuids
          calc = FactoryGirl.create(
            :assignment_pe_calculation,
            student_uuid: @reading_3.student_uuid,
            ecosystem_uuid: @reading_3.ecosystem_uuid,
            book_container_uuid: reading_3_assigned_pe_pool.book_container_uuid,
            assignment_uuid: @reading_3.uuid,
            exercise_uuids: reading_3_available_pe_uuids,
            exercise_count: 1
          )
          FactoryGirl.create :algorithm_assignment_pe_calculation,
                             assignment_pe_calculation_uuid: calc.uuid

          reading_3_assigned_spe_pool = @reading_pool_1_new
          [ :instructor_driven, :student_driven ].each do |history_type|
            calc = FactoryGirl.create(
              :assignment_spe_calculation,
              student_uuid: @reading_3.student_uuid,
              ecosystem_uuid: @reading_3.ecosystem_uuid,
              book_container_uuid: reading_3_assigned_spe_pool.book_container_uuid,
              assignment_uuid: @reading_3.uuid,
              history_type: history_type,
              k_ago: 2,
              exercise_uuids: reading_3_assigned_spe_pool.exercise_uuids,
              exercise_count: 1
            )
            FactoryGirl.create :algorithm_assignment_spe_calculation,
                               assignment_spe_calculation_uuid: calc.uuid
          end

          homework_3_assigned_spe_pool = @homework_pool_1_new
          [ :instructor_driven, :student_driven ].each do |history_type|
            calc = FactoryGirl.create(
              :assignment_spe_calculation,
              student_uuid: @homework_3.student_uuid,
              ecosystem_uuid: @homework_3.ecosystem_uuid,
              book_container_uuid: homework_3_assigned_spe_pool.book_container_uuid,
              assignment_uuid: @homework_3.uuid,
              history_type: history_type,
              k_ago: 2,
              exercise_uuids: homework_3_assigned_spe_pool.exercise_uuids,
              exercise_count: 1
            )
            FactoryGirl.create :algorithm_assignment_spe_calculation,
                               assignment_spe_calculation_uuid: calc.uuid
          end
        end

        after(:all)  { DatabaseCleaner.clean }

        it 'creates only the missing SPE and PE calculations with the correct pools' do
        expect { subject.process }.to  change { AssignmentSpeCalculation.count          }
                                         .by(expected_assignment_spe_calculations.size - 4)
                                  .and change { AssignmentSpeCalculationExercise.count  }
                                  .and change { AlgorithmAssignmentSpeCalculation.count }.by(-4)
                                  .and change { AssignmentPeCalculation.count           }
                                         .by(expected_assignment_pe_calculations.size - 1)
                                  .and change { AssignmentPeCalculationExercise.count   }
                                  .and change { AlgorithmAssignmentPeCalculation.count  }.by(-1)

          AssignmentSpeCalculation.all.each do |calc|
            index = [calc.assignment_uuid, calc.book_container_uuid, calc.history_type, calc.k_ago]
            expected_calculation = indexed_assignment_spe_calculations.fetch index
            expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
            expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
          end

          AssignmentPeCalculation.all.each do |calc|
            index = [calc.assignment_uuid, calc.book_container_uuid]
            expected_calculation = indexed_assignment_pe_calculations.fetch index
            expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
            expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
          end
        end
      end
    end

    context 'with assignments completed in the reverse order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ].reverse
      end

      let(:expected_assignment_spe_calculations) do
        [
          {
            assignment_uuid: @reading_2.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_3_new.exercise_uuids +
                            @reading_pool_4_new.exercise_uuids -
                            @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_2.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_3_new.exercise_uuids +
                            @reading_pool_4_new.exercise_uuids -
                            @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: @reading_pool_1_new.book_container_uuid,
            exercise_uuids: @reading_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_4_new.exercise_uuids +
                            @reading_pool_5_new.exercise_uuids -
                            @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_4_new.exercise_uuids +
                            @reading_pool_5_new.exercise_uuids -
                            @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: @reading_pool_4_new.exercise_uuids +
                            @reading_pool_5_new.exercise_uuids -
                            @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: @homework_pool_4_old.book_container_uuid,
            exercise_uuids: @homework_pool_4_old.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_2.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_2.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 2,
            book_container_uuid: @homework_pool_1_new.book_container_uuid,
            exercise_uuids: @homework_pool_1_new.exercise_uuids,
            exercise_count: 1
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            k_ago: 2,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          },
          {
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            k_ago: 4,
            book_container_uuid: nil,
            exercise_uuids: [],
            exercise_count: 0
          }
        ]
      end

      it 'creates the correct numbers of SPE and PE calculations with the correct pools' do
        expected_num_spes = expected_assignment_spe_calculations
                              .map { |calc| calc[:exercise_uuids].size }
                              .reduce(0, :+)
        expected_num_pes = expected_assignment_pe_calculations
                             .map { |calc| calc[:exercise_uuids].size }
                             .reduce(0, :+)
        expect { subject.process }.to  change     { AssignmentSpeCalculation.count          }
                                         .by(expected_assignment_spe_calculations.size)
                                  .and change     { AssignmentSpeCalculationExercise.count  }
                                         .by(expected_num_spes)
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and change     { AssignmentPeCalculation.count           }
                                         .by(expected_assignment_pe_calculations.size)
                                  .and change     { AssignmentPeCalculationExercise.count   }
                                         .by(expected_num_pes)
                                  .and not_change { AlgorithmAssignmentPeCalculation.count  }

        AssignmentSpeCalculation.all.each do |calc|
          index = [calc.assignment_uuid, calc.book_container_uuid, calc.history_type, calc.k_ago]
          expected_calculation = indexed_assignment_spe_calculations.fetch index
          expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
          expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
        end

        AssignmentPeCalculation.all.each do |calc|
          index = [calc.assignment_uuid, calc.book_container_uuid]
          expected_calculation = indexed_assignment_pe_calculations.fetch index
          expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
          expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
        end
      end

      context 'with some pre-existing calculations' do
        before(:all) do
          DatabaseCleaner.start

          reading_3_assigned_pe_pool = [@reading_pool_4_new, @reading_pool_5_new].sample
          reading_3_available_pe_uuids = reading_3_assigned_pe_pool.exercise_uuids -
                                         @reading_3.assigned_exercise_uuids
          calc = FactoryGirl.create(
            :assignment_pe_calculation,
            student_uuid: @reading_3.student_uuid,
            ecosystem_uuid: @reading_3.ecosystem_uuid,
            book_container_uuid: reading_3_assigned_pe_pool.book_container_uuid,
            assignment_uuid: @reading_3.uuid,
            exercise_uuids: reading_3_available_pe_uuids,
            exercise_count: 1
          )
          FactoryGirl.create :algorithm_assignment_pe_calculation,
                             assignment_pe_calculation_uuid: calc.uuid

          reading_3_assigned_instructor_spe_pool = @reading_pool_1_new
          calc = FactoryGirl.create(
            :assignment_spe_calculation,
            student_uuid: @reading_3.student_uuid,
            ecosystem_uuid: @reading_3.ecosystem_uuid,
            book_container_uuid: reading_3_assigned_instructor_spe_pool.book_container_uuid,
            assignment_uuid: @reading_3.uuid,
            history_type: :instructor_driven,
            k_ago: 2,
            exercise_uuids: reading_3_assigned_instructor_spe_pool.exercise_uuids,
            exercise_count: 1
          )
          FactoryGirl.create :algorithm_assignment_spe_calculation,
                             assignment_spe_calculation_uuid: calc.uuid

          homework_3_assigned_instructor_spe_pool = @homework_pool_1_new
          calc = FactoryGirl.create(
            :assignment_spe_calculation,
            student_uuid: @homework_3.student_uuid,
            ecosystem_uuid: @homework_3.ecosystem_uuid,
            book_container_uuid: homework_3_assigned_instructor_spe_pool.book_container_uuid,
            assignment_uuid: @homework_3.uuid,
            history_type: :instructor_driven,
            k_ago: 2,
            exercise_uuids: homework_3_assigned_instructor_spe_pool.exercise_uuids,
            exercise_count: 1
          )
          FactoryGirl.create :algorithm_assignment_spe_calculation,
                             assignment_spe_calculation_uuid: calc.uuid

          homework_1_assigned_student_spe_pool = @homework_pool_4_old
          calc = FactoryGirl.create(
            :assignment_spe_calculation,
            student_uuid: @homework_1.student_uuid,
            ecosystem_uuid: @homework_1.ecosystem_uuid,
            book_container_uuid: homework_1_assigned_student_spe_pool.book_container_uuid,
            assignment_uuid: @homework_1.uuid,
            history_type: :student_driven,
            k_ago: 2,
            exercise_uuids: homework_1_assigned_student_spe_pool.exercise_uuids,
            exercise_count: 1
          )
          FactoryGirl.create :algorithm_assignment_spe_calculation,
                             assignment_spe_calculation_uuid: calc.uuid
        end

        after(:all)  { DatabaseCleaner.clean }

        it 'creates only the missing SPE and PE calculations with the correct pools' do
          expect { subject.process }.to  change { AssignmentSpeCalculation.count          }
                                           .by(expected_assignment_spe_calculations.size - 3)
                                    .and change { AssignmentSpeCalculationExercise.count  }
                                    .and change { AlgorithmAssignmentSpeCalculation.count }.by(-3)
                                    .and change { AssignmentPeCalculation.count           }
                                           .by(expected_assignment_pe_calculations.size - 1)
                                    .and change { AlgorithmAssignmentPeCalculation.count  }.by(-1)
                                    .and change { AssignmentPeCalculationExercise.count   }

          AssignmentSpeCalculation.all.each do |calc|
            index = [calc.assignment_uuid, calc.book_container_uuid, calc.history_type, calc.k_ago]
            expected_calculation = indexed_assignment_spe_calculations.fetch index
            expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
            expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
          end

          AssignmentPeCalculation.all.each do |calc|
            index = [calc.assignment_uuid, calc.book_container_uuid]
            expected_calculation = indexed_assignment_pe_calculations.fetch index
            expect(calc.exercise_uuids).to match_array expected_calculation[:exercise_uuids]
            expect(calc.exercise_count).to eq expected_calculation[:exercise_count]
          end
        end
      end
    end
  end
end

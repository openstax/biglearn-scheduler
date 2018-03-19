require 'rails_helper'

RSpec.describe Services::PrepareExerciseCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments or Responses' do
    it 'does not create any SPE or PE calculations' do
      expect { subject.process }.to  not_change { ExerciseCalculation.count          }
                                .and not_change { AlgorithmExerciseCalculation.count }
    end
  end

  context 'with existing Assignments and Responses' do
    before(:all) do
      DatabaseCleaner.start

      @ecosystem_1 = FactoryGirl.create :ecosystem
      @ecosystem_2 = FactoryGirl.create :ecosystem
      @ecosystem_3 = FactoryGirl.create :ecosystem
      @ecosystem_4 = FactoryGirl.create :ecosystem

      @reading_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: @ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_1.uuid,
                         to_ecosystem_uuid: @ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_2.uuid,
                         to_ecosystem_uuid: @ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_1_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_old.book_container_uuid
      @reading_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: @ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_3.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_2.uuid,
                         to_ecosystem_uuid: @ecosystem_3.uuid,
                         from_book_container_uuid: @reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_3.uuid,
                         to_ecosystem_uuid: @ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_2_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_old.book_container_uuid

      @homework_pool_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: @ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      @homework_pool_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )

      practice_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_old.exercise_uuids + @homework_pool_old.exercise_uuids,
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      practice_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_new.exercise_uuids + @homework_pool_new.exercise_uuids,
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      practice_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_old.exercise_uuids,
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      practice_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_3.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_new.exercise_uuids,
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )

      exercise_uuids = [ practice_pool_1_new, practice_pool_2_new ].flat_map(&:exercise_uuids)
      exercise_uuids.each { |exercise_uuid| FactoryGirl.create :exercise, uuid: exercise_uuid }

      course = FactoryGirl.create :course, ecosystem_uuid: @ecosystem_4.uuid
      @student_1 = FactoryGirl.create :student, course: course
      @student_2 = FactoryGirl.create :student, course: course

      # Biglearn exercises requested
      @reading_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_1.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: @ecosystem_1.uuid,
        assigned_exercise_uuids: @reading_pool_1_old.exercise_uuids.sample(5),
        assigned_book_container_uuids: [ @reading_pool_1_old.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 3,
        pes_are_assigned: false,
        has_exercise_calculation: true
      )
      @reading_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_2.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: @ecosystem_1.uuid,
        assigned_exercise_uuids: @reading_pool_1_old.exercise_uuids.sample(5),
        assigned_book_container_uuids: [ @reading_pool_1_old.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 3,
        pes_are_assigned: false,
        has_exercise_calculation: true
      )
      @reading_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_1.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: @ecosystem_3.uuid,
        assigned_exercise_uuids: @reading_pool_2_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [ @reading_pool_2_new.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 3,
        pes_are_assigned: false,
        has_exercise_calculation: true
      )
      @reading_4 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_2.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: @ecosystem_3.uuid,
        assigned_exercise_uuids: @reading_pool_2_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [ @reading_pool_2_new.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 3,
        pes_are_assigned: false,
        has_exercise_calculation: false
      )

      # No Biglearn exercises requested
      @homework_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_1.uuid,
        assignment_type: 'homework',
        ecosystem_uuid: @ecosystem_2.uuid,
        assigned_exercise_uuids: @homework_pool_old.exercise_uuids,
        assigned_book_container_uuids: [ @homework_pool_old.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: true,
        goal_num_tutor_assigned_pes: 0,
        pes_are_assigned: false,
        has_exercise_calculation: true
      )
      @homework_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: @student_2.uuid,
        assignment_type: 'homework',
        ecosystem_uuid: @ecosystem_2.uuid,
        assigned_exercise_uuids: @homework_pool_old.exercise_uuids,
        assigned_book_container_uuids: [ @homework_pool_old.book_container_uuid ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: true,
        goal_num_tutor_assigned_pes: 0,
        pes_are_assigned: false,
        has_exercise_calculation: true
      )
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:expected_exercise_calculations) do
      [
        {
          ecosystem_uuid: @ecosystem_1.uuid,
          student_uuid: @student_1.uuid
        },
        {
          ecosystem_uuid: @ecosystem_3.uuid,
          student_uuid: @student_1.uuid
        },
        {
          ecosystem_uuid: @ecosystem_4.uuid,
          student_uuid: @student_1.uuid
        },
        {
          ecosystem_uuid: @ecosystem_3.uuid,
          student_uuid: @student_2.uuid
        },
        {
          ecosystem_uuid: @ecosystem_4.uuid,
          student_uuid: @student_2.uuid
        }
      ]
    end

    let!(:responses) do
      [ @reading_1, @homework_1 ].flat_map do |assignment|
        student_uuid = assignment.student_uuid

        assignment.assigned_exercise_uuids.map do |assigned_exercise_uuid|
          FactoryGirl.create :response, student_uuid: student_uuid,
                                        exercise_uuid: assigned_exercise_uuid
        end
      end
    end

    let(:exercise_calculation_attributes_set) do
      Set.new expected_exercise_calculations.map do |calc|
        [ calc[:student_uuid], calc[:ecosystem_uuid] ]
      end
    end

    context 'with no pre-existing ExerciseCalculations' do
      it 'creates the correct numbers of ExerciseCalculations with the correct ecosystems' do
        expect { subject.process }.to  change     { ExerciseCalculation.count          }
                                                    .by(expected_exercise_calculations.size)
                                  .and not_change { AlgorithmExerciseCalculation.count }

        ExerciseCalculation.pluck(:student_uuid, :ecosystem_uuid).each do |attributes|
          expect(exercise_calculation_attributes_set).to include attributes
        end
      end
    end

    context 'with some pre-existing ExerciseCalculations' do
      before(:all) do
        DatabaseCleaner.start

        @existing_calculation = FactoryGirl.create(
          :exercise_calculation,
          ecosystem: @ecosystem_1,
          student: @student_1
        )

        FactoryGirl.create :algorithm_exercise_calculation,
                           exercise_calculation: @existing_calculation
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'changes the uuid of existing ExerciseCalculations to trigger their recalculation' do
        expect { subject.process }.to  change { ExerciseCalculation.count               }
                                         .by(expected_exercise_calculations.size - 1)
                                  .and change { AlgorithmExerciseCalculation.count  }.by(-1)

        ExerciseCalculation.pluck(:student_uuid, :ecosystem_uuid).each do |attributes|
          expect(exercise_calculation_attributes_set).to include attributes
        end
      end
    end
  end
end

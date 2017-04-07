require 'rails_helper'

RSpec.describe Services::PrepareStudentExerciseCalculations::Service, type: :service do
  subject { described_class.new }

  context 'with no Students' do
    it 'does not create any PE calculations' do
      expect { subject.process }.to  not_change { StudentPeCalculation.count         }
                                .and not_change { StudentPeCalculationExercise.count }
    end
  end

  context 'with existing ExercisePools, Exercises,' +
          ' BookContainerMappings, Course, Student and StudentClues' do
    before(:all) do
      DatabaseCleaner.start

      @ecosystem_uuid_1 = SecureRandom.uuid
      @ecosystem_uuid_2 = SecureRandom.uuid

      @reading_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_uuid_1,
                         to_ecosystem_uuid: @ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_new.book_container_uuid
      @reading_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: @ecosystem_uuid_1,
                         to_ecosystem_uuid: @ecosystem_uuid_2,
                         from_book_container_uuid: @reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_new.book_container_uuid
      @reading_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['reading']
      )

      @homework_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      @homework_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_1_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      @homework_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 4,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      @homework_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_2_old.exercise_uuids,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      @homework_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      @homework_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      @homework_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      @practice_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_old.exercise_uuids + @homework_pool_1_old.exercise_uuids,
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      @practice_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_new.exercise_uuids + @homework_pool_1_new.exercise_uuids,
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      @practice_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_1,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_old.exercise_uuids + @homework_pool_2_old.exercise_uuids,
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      @practice_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_new.exercise_uuids + @homework_pool_2_new.exercise_uuids,
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      @practice_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_3_new.exercise_uuids + @homework_pool_3_new.exercise_uuids,
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      @practice_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_4_new.exercise_uuids + @homework_pool_4_new.exercise_uuids,
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      @practice_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: @ecosystem_uuid_2,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_5_new.exercise_uuids + @homework_pool_5_new.exercise_uuids,
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      exercise_uuids = [
        @practice_pool_1_new,
        @practice_pool_2_new,
        @practice_pool_3_new,
        @practice_pool_4_new,
        @practice_pool_5_new
      ].flat_map(&:exercise_uuids)
      exercise_uuids.each { |exercise_uuid| FactoryGirl.create :exercise, uuid: exercise_uuid }

      @course = FactoryGirl.create :course, ecosystem_uuid: @ecosystem_uuid_2
      @student = FactoryGirl.create :student, course_uuid: @course.uuid, pes_are_assigned: false

      @clue_algorithm_name = 'sparfa'

      scc_1 = FactoryGirl.create :student_clue_calculation,
                                 student_uuid: @student.uuid,
                                 book_container_uuid: @practice_pool_1_new.book_container_uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation_uuid: scc_1.uuid,
                         algorithm_name: @clue_algorithm_name,
                         ecosystem_uuid: @ecosystem_uuid_2,
                         book_container_uuid: @practice_pool_1_new.book_container_uuid,
                         student_uuid: @student.uuid,
                         clue_value: 0.25
      scc_2 = FactoryGirl.create :student_clue_calculation,
                                 student_uuid: @student.uuid,
                                 book_container_uuid: @practice_pool_2_new.book_container_uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation_uuid: scc_2.uuid,
                         algorithm_name: @clue_algorithm_name,
                         ecosystem_uuid: @ecosystem_uuid_2,
                         book_container_uuid: @practice_pool_2_new.book_container_uuid,
                         student_uuid: @student.uuid,
                         clue_value: 0
      scc_3 = FactoryGirl.create :student_clue_calculation,
                                 student_uuid: @student.uuid,
                                 book_container_uuid: @practice_pool_3_new.book_container_uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation_uuid: scc_3.uuid,
                         algorithm_name: @clue_algorithm_name,
                         ecosystem_uuid: @ecosystem_uuid_2,
                         book_container_uuid: @practice_pool_3_new.book_container_uuid,
                         student_uuid: @student.uuid,
                         clue_value: 0.5
      scc_4 = FactoryGirl.create :student_clue_calculation,
                                 student_uuid: @student.uuid,
                                 book_container_uuid: @practice_pool_4_new.book_container_uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation_uuid: scc_4.uuid,
                         algorithm_name: @clue_algorithm_name,
                         ecosystem_uuid: @ecosystem_uuid_2,
                         book_container_uuid: @practice_pool_4_new.book_container_uuid,
                         student_uuid: @student.uuid,
                         clue_value: 0.75
      scc_5 = FactoryGirl.create :student_clue_calculation,
                                 student_uuid: @student.uuid,
                                 book_container_uuid: @practice_pool_5_new.book_container_uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation_uuid: scc_5.uuid,
                         algorithm_name: @clue_algorithm_name,
                         ecosystem_uuid: @ecosystem_uuid_2,
                         book_container_uuid: @practice_pool_5_new.book_container_uuid,
                         student_uuid: @student.uuid,
                         clue_value: 1
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:practice_pools) do
      [
        @practice_pool_1_new,
        @practice_pool_2_new,
        @practice_pool_3_new,
        @practice_pool_4_new,
        @practice_pool_5_new
      ]
    end
    let(:practice_pool_by_book_container_uuid) { practice_pools.index_by(&:book_container_uuid) }

    it 'creates the correct numbers of PE calculations with the correct exercise pools' do
      expected_num_calculations = [practice_pools.size, 5].min
      expected_num_pes = practice_pools.flat_map(&:exercise_uuids).size
      expect { subject.process }.to  change { StudentPeCalculation.count         }
                                              .by(expected_num_calculations)
                                .and change { StudentPeCalculationExercise.count }
                                              .by(expected_num_pes)

      student_pe_calculations = StudentPeCalculation.order(:created_at).last(5)
      book_container_uuids = student_pe_calculations.map(&:book_container_uuid)
      expect(book_container_uuids).to match_array practice_pool_by_book_container_uuid.keys

      student_pe_calculations.each do |student_pe_calculation|
        book_container_uuid = student_pe_calculation.book_container_uuid
        practice_pool = practice_pool_by_book_container_uuid.fetch book_container_uuid

        student_pe_calculation.exercise_uuids.each do |exercise_uuid|
          expect(exercise_uuid).to be_in practice_pool.exercise_uuids
        end
        expect(student_pe_calculation.exercise_count).to eq 1
      end
    end

    context 'with some pre-existing calculations' do
      before(:all) do
        DatabaseCleaner.start

        @already_assigned_exercise_pools = [ @practice_pool_1_new, @practice_pool_2_new ]
        @already_assigned_exercise_pools.each do |exercise_pool|
          FactoryGirl.create :student_pe_calculation,
                             clue_algorithm_name: @clue_algorithm_name,
                             book_container_uuid: exercise_pool.book_container_uuid,
                             student_uuid: @student.uuid,
                             exercise_uuids: exercise_pool.exercise_uuids,
                             exercise_count: 1
        end
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'creates only the missing PE calculations with the correct exercise pools' do
        expected_num_calculations = [practice_pools.size, 5].min
        expected_change_in_calculations = expected_num_calculations -
                                          @already_assigned_exercise_pools.size
        expected_num_pes = practice_pools.flat_map(&:exercise_uuids).size
        expect { subject.process }.to  change { StudentPeCalculation.count         }
                                                .by(expected_change_in_calculations)
                                  .and change { StudentPeCalculationExercise.count }
                                                .by(expected_num_pes)

        student_pe_calculations = StudentPeCalculation.order(:created_at).last(5)
        book_container_uuids = student_pe_calculations.map(&:book_container_uuid)
        expect(book_container_uuids).to match_array practice_pool_by_book_container_uuid.keys

        student_pe_calculations.each do |student_pe_calculation|
          book_container_uuid = student_pe_calculation.book_container_uuid
          practice_pool = practice_pool_by_book_container_uuid.fetch book_container_uuid

          student_pe_calculation.exercise_uuids.each do |exercise_uuid|
            expect(exercise_uuid).to be_in practice_pool.exercise_uuids
          end
          expect(student_pe_calculation.exercise_count).to eq 1
        end
      end
    end
  end
end

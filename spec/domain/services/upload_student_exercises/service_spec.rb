require 'rails_helper'

RSpec.describe Services::UploadStudentExercises::Service, type: :service do
  subject { described_class.new }

  context 'with no Students' do
    it 'does not create any PEs' do
      expect { subject.process }.not_to change { StudentPe.count }
    end
  end

  context 'with existing Ecosystems, Course, Student, ExercisePools, Exercises,' +
          ' BookContainerMappings, Student, StudentClues, ExerciseCalculations' +
          ' and AlgorithmExerciseCalculations' do
    before(:all) do
      DatabaseCleaner.start

      ecosystem_1 = FactoryGirl.create :ecosystem
      ecosystem_2 = FactoryGirl.create :ecosystem

      course = FactoryGirl.create :course, ecosystem_uuid: ecosystem_2.uuid
      student = FactoryGirl.create :student, course: course

      reading_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_1_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_1_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_1_old.book_container_uuid
      reading_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_2_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_2_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_2_old.book_container_uuid
      reading_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_3_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_3_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_3_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_3_old.book_container_uuid
      reading_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_4_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_4_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_4_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_4_old.book_container_uuid
      reading_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_5_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_5_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_5_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_5_old.book_container_uuid

      homework_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_1_old.book_container_uuid
      )
      homework_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: homework_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_1_new.book_container_uuid
      )
      homework_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 4,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_2_old.book_container_uuid
      )
      homework_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: homework_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_2_new.book_container_uuid
      )
      homework_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_3_old.book_container_uuid
      )
      homework_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_3_new.book_container_uuid
      )
      homework_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_4_old.book_container_uuid
      )
      homework_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_4_new.book_container_uuid
      )
      homework_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_5_old.book_container_uuid
      )
      homework_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_5_new.book_container_uuid
      )

      practice_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_1_old.exercise_uuids + homework_pool_1_old.exercise_uuids,
        book_container_uuid: reading_pool_1_old.book_container_uuid
      )
      @practice_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_1_new.exercise_uuids + homework_pool_1_new.exercise_uuids,
        book_container_uuid: reading_pool_1_new.book_container_uuid
      )
      practice_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_2_old.exercise_uuids + homework_pool_2_old.exercise_uuids,
        book_container_uuid: reading_pool_2_old.book_container_uuid
      )
      @practice_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_2_new.exercise_uuids + homework_pool_2_new.exercise_uuids,
        book_container_uuid: reading_pool_2_new.book_container_uuid
      )
      practice_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_3_old.exercise_uuids + homework_pool_3_old.exercise_uuids,
        book_container_uuid: reading_pool_3_old.book_container_uuid
      )
      @practice_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_3_new.exercise_uuids + homework_pool_3_new.exercise_uuids,
        book_container_uuid: reading_pool_3_new.book_container_uuid
      )
      practice_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_4_old.exercise_uuids + homework_pool_4_old.exercise_uuids,
        book_container_uuid: reading_pool_4_old.book_container_uuid
      )
      @practice_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_4_new.exercise_uuids + homework_pool_4_new.exercise_uuids,
        book_container_uuid: reading_pool_4_new.book_container_uuid
      )
      practice_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_5_old.exercise_uuids + homework_pool_5_old.exercise_uuids,
        book_container_uuid: reading_pool_5_old.book_container_uuid
      )
      @practice_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_5_new.exercise_uuids + homework_pool_5_new.exercise_uuids,
        book_container_uuid: reading_pool_5_new.book_container_uuid
      )

      old_exercise_uuids = [
        practice_pool_1_old,
        practice_pool_2_old,
        practice_pool_3_old,
        practice_pool_4_old,
        practice_pool_5_old
      ].flat_map(&:exercise_uuids)
      new_exercise_uuids = [
        @practice_pool_1_new,
        @practice_pool_2_new,
        @practice_pool_3_new,
        @practice_pool_4_new,
        @practice_pool_5_new
      ].flat_map(&:exercise_uuids)
      new_exercise_uuids.each { |exercise_uuid| FactoryGirl.create :exercise, uuid: exercise_uuid }

      @clue_algorithm_name = 'sparfa'

      scc_1 = FactoryGirl.create :student_clue_calculation,
                                 ecosystem_uuid: ecosystem_2.uuid,
                                 book_container_uuid: @practice_pool_1_new.book_container_uuid,
                                 student_uuid: student.uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation: scc_1,
                         algorithm_name: @clue_algorithm_name,
                         clue_value: 0.25
      scc_2 = FactoryGirl.create :student_clue_calculation,
                                 ecosystem_uuid: ecosystem_2.uuid,
                                 book_container_uuid: @practice_pool_2_new.book_container_uuid,
                                 student_uuid: student.uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation: scc_2,
                         algorithm_name: @clue_algorithm_name,
                         clue_value: 0
      scc_3 = FactoryGirl.create :student_clue_calculation,
                                 ecosystem_uuid: ecosystem_2.uuid,
                                 book_container_uuid: @practice_pool_3_new.book_container_uuid,
                                 student_uuid: student.uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation: scc_3,
                         algorithm_name: @clue_algorithm_name,
                         clue_value: 0.5
      scc_4 = FactoryGirl.create :student_clue_calculation,
                                 ecosystem_uuid: ecosystem_2.uuid,
                                 book_container_uuid: @practice_pool_4_new.book_container_uuid,
                                 student_uuid: student.uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation: scc_4,
                         algorithm_name: @clue_algorithm_name,
                         clue_value: 0.75
      scc_5 = FactoryGirl.create :student_clue_calculation,
                                 ecosystem_uuid: ecosystem_2.uuid,
                                 book_container_uuid: @practice_pool_5_new.book_container_uuid,
                                 student_uuid: student.uuid
      FactoryGirl.create :algorithm_student_clue_calculation,
                         student_clue_calculation: scc_5,
                         algorithm_name: @clue_algorithm_name,
                         clue_value: 1

      exercise_calculation_1 = FactoryGirl.create(
        :exercise_calculation,
        ecosystem: ecosystem_1,
        student_uuid: student.uuid
      )
      @algorithm_exercise_calculation_1 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_1,
        algorithm_name: 'local_query',
        exercise_uuids: old_exercise_uuids.shuffle,
        is_uploaded_for_student: false
      )
      @algorithm_exercise_calculation_2 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_1,
        algorithm_name: 'tesr',
        exercise_uuids: old_exercise_uuids.shuffle,
        is_uploaded_for_student: false
      )

      exercise_calculation_2 = FactoryGirl.create(
        :exercise_calculation,
        ecosystem: ecosystem_2,
        student_uuid: student.uuid
      )
      @algorithm_exercise_calculation_3 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_2,
        algorithm_name: 'local_query',
        exercise_uuids: new_exercise_uuids.shuffle,
        is_uploaded_for_student: false
      )
      @algorithm_exercise_calculation_4 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_2,
        algorithm_name: 'tesr',
        exercise_uuids: new_exercise_uuids.shuffle,
        is_uploaded_for_student: false
      )
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:expected_num_spes) do
      expected_student_pes.map { |calc| calc[:exercise_count] }.reduce(0, :+)
    end
    let(:expected_num_pes) do
      expected_student_pes.map { |calc| calc[:exercise_count] }.reduce(0, :+)
    end

    # There are no CLUes for local_query above, so there are no local_query StudentPes
    let(:expected_student_pes) do
      [
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_3,
          exercise_pool: [],
          exercise_count: 0
        },
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_4,
          exercise_pool: @practice_pool_1_new.exercise_uuids +
                         @practice_pool_2_new.exercise_uuids +
                         @practice_pool_3_new.exercise_uuids +
                         @practice_pool_4_new.exercise_uuids +
                         @practice_pool_5_new.exercise_uuids,
          exercise_count: 5
        }
      ]
    end

    before do
      expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas).with(
        [a_kind_of(Hash)] * expected_student_pes.size
      )
    end

    it 'creates the correct numbers of Biglearn requests and PEs from the correct pools' do
      expect { subject.process }.to  change { StudentPe.count }.by(expected_num_pes)

      expected_student_pes.each do |expected_student_pe|
        algorithm_exercise_calculation_uuid =
          expected_student_pe[:algorithm_exercise_calculation].uuid
        student_pes = StudentPe.where(
          algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid
        )

        expect(student_pes.size).to eq expected_student_pe[:exercise_count]

        student_pes.each do |student_pe|
          expect(student_pe.exercise_uuid).to be_in expected_student_pe[:exercise_pool]
        end
      end
    end
  end
end

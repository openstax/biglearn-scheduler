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

      ecosystem_1 = FactoryBot.create :ecosystem
      ecosystem_2 = FactoryBot.create :ecosystem

      course = FactoryBot.create :course, ecosystem_uuid: ecosystem_2.uuid
      student = FactoryBot.create :student, course: course

      reading_pool_1_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_1_new = FactoryBot.create(
        :exercise_pool,
        exercise_uuids: reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_1_new.book_container_uuid
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_1_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_1_old.book_container_uuid
      reading_pool_2_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_2_new = FactoryBot.create(
        :exercise_pool,
        exercise_uuids: reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_2_new.book_container_uuid
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_2_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_2_old.book_container_uuid
      reading_pool_3_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_3_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_3_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_3_new.book_container_uuid
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_3_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_3_old.book_container_uuid
      reading_pool_4_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_4_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_4_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_4_new.book_container_uuid
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_4_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_4_old.book_container_uuid
      reading_pool_5_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      reading_pool_5_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: reading_pool_5_old.book_container_uuid,
                         to_book_container_uuid: reading_pool_5_new.book_container_uuid
      FactoryBot.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: reading_pool_5_new.book_container_uuid,
                         to_book_container_uuid: reading_pool_5_old.book_container_uuid

      homework_pool_1_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_1_old.book_container_uuid
      )
      homework_pool_1_new = FactoryBot.create(
        :exercise_pool,
        exercise_uuids: homework_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_1_new.book_container_uuid
      )
      homework_pool_2_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 4,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_2_old.book_container_uuid
      )
      homework_pool_2_new = FactoryBot.create(
        :exercise_pool,
        exercise_uuids: homework_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_2_new.book_container_uuid
      )
      homework_pool_3_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_3_old.book_container_uuid
      )
      homework_pool_3_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_3_new.book_container_uuid
      )
      homework_pool_4_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_4_old.book_container_uuid
      )
      homework_pool_4_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_4_new.book_container_uuid
      )
      homework_pool_5_old = FactoryBot.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_5_old.book_container_uuid
      )
      homework_pool_5_new = FactoryBot.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: reading_pool_5_new.book_container_uuid
      )

      practice_pool_1_old = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_1_old.exercise_uuids + homework_pool_1_old.exercise_uuids,
        book_container_uuid: reading_pool_1_old.book_container_uuid
      )
      @practice_pool_1_new = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_1_new.exercise_uuids + homework_pool_1_new.exercise_uuids,
        book_container_uuid: reading_pool_1_new.book_container_uuid
      )
      practice_pool_2_old = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_2_old.exercise_uuids + homework_pool_2_old.exercise_uuids,
        book_container_uuid: reading_pool_2_old.book_container_uuid
      )
      @practice_pool_2_new = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_2_new.exercise_uuids + homework_pool_2_new.exercise_uuids,
        book_container_uuid: reading_pool_2_new.book_container_uuid
      )
      practice_pool_3_old = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_3_old.exercise_uuids + homework_pool_3_old.exercise_uuids,
        book_container_uuid: reading_pool_3_old.book_container_uuid
      )
      @practice_pool_3_new = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_3_new.exercise_uuids + homework_pool_3_new.exercise_uuids,
        book_container_uuid: reading_pool_3_new.book_container_uuid
      )
      practice_pool_4_old = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_4_old.exercise_uuids + homework_pool_4_old.exercise_uuids,
        book_container_uuid: reading_pool_4_old.book_container_uuid
      )
      @practice_pool_4_new = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_4_new.exercise_uuids + homework_pool_4_new.exercise_uuids,
        book_container_uuid: reading_pool_4_new.book_container_uuid
      )
      practice_pool_5_old = FactoryBot.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: reading_pool_5_old.exercise_uuids + homework_pool_5_old.exercise_uuids,
        book_container_uuid: reading_pool_5_old.book_container_uuid
      )
      @practice_pool_5_new = FactoryBot.create(
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
      new_exercise_uuids.each { |exercise_uuid| FactoryBot.create :exercise, uuid: exercise_uuid }

      local_query_algorithm_name = 'local_query'
      sparfa_algorithm_name = 'biglearn_sparfa'
      @clue_algorithm_name = sparfa_algorithm_name

      @scc_1 = FactoryBot.create :student_clue_calculation,
                                  ecosystem_uuid: ecosystem_2.uuid,
                                  book_container_uuid: @practice_pool_1_new.book_container_uuid,
                                  student_uuid: student.uuid
      @scc_2 = FactoryBot.create :student_clue_calculation,
                                  ecosystem_uuid: ecosystem_2.uuid,
                                  book_container_uuid: @practice_pool_2_new.book_container_uuid,
                                  student_uuid: student.uuid
      @scc_3 = FactoryBot.create :student_clue_calculation,
                                  ecosystem_uuid: ecosystem_2.uuid,
                                  book_container_uuid: @practice_pool_3_new.book_container_uuid,
                                  student_uuid: student.uuid
      @scc_4 = FactoryBot.create :student_clue_calculation,
                                  ecosystem_uuid: ecosystem_2.uuid,
                                  book_container_uuid: @practice_pool_4_new.book_container_uuid,
                                  student_uuid: student.uuid
      @scc_5 = FactoryBot.create :student_clue_calculation,
                                  ecosystem_uuid: ecosystem_2.uuid,
                                  book_container_uuid: @practice_pool_5_new.book_container_uuid,
                                  student_uuid: student.uuid

      exercise_calculation_1 = FactoryBot.create(
        :exercise_calculation,
        ecosystem: ecosystem_1,
        student_uuid: student.uuid
      )
      @algorithm_exercise_calculation_1 = FactoryBot.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_1,
        algorithm_name: local_query_algorithm_name,
        exercise_uuids: old_exercise_uuids.shuffle,
        is_pending_for_student: true
      )
      @algorithm_exercise_calculation_2 = FactoryBot.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_1,
        algorithm_name: sparfa_algorithm_name,
        exercise_uuids: old_exercise_uuids.shuffle,
        is_pending_for_student: true
      )

      exercise_calculation_2 = FactoryBot.create(
        :exercise_calculation,
        ecosystem: ecosystem_2,
        student_uuid: student.uuid
      )
      @algorithm_exercise_calculation_3 = FactoryBot.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_2,
        algorithm_name: local_query_algorithm_name,
        exercise_uuids: new_exercise_uuids.shuffle,
        is_pending_for_student: true
      )
      @algorithm_exercise_calculation_4 = FactoryBot.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_2,
        algorithm_name: sparfa_algorithm_name,
        exercise_uuids: new_exercise_uuids.shuffle,
        is_pending_for_student: true
      )
    end

    after(:all)  { DatabaseCleaner.clean }

    context 'and AlgorithmStudentClueCalculations' do
      before(:all) do
        DatabaseCleaner.start

        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: @scc_1,
                           algorithm_name: @clue_algorithm_name,
                           clue_value: 0.25
        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: @scc_2,
                           algorithm_name: @clue_algorithm_name,
                           clue_value: 0
        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: @scc_3,
                           algorithm_name: @clue_algorithm_name,
                           clue_value: 0.5
        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: @scc_4,
                           algorithm_name: @clue_algorithm_name,
                           clue_value: 0.75
        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: @scc_5,
                           algorithm_name: @clue_algorithm_name,
                           clue_value: 1
      end

      after(:all)  { DatabaseCleaner.clean }

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
        expect { subject.process }.to change { StudentPe.count }.by(expected_num_pes)

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

    context 'and initially no AlgorithmStudentClueCalculations' do
      before do
        expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas) do |requests|
          requests.each { |request| expect(request).to be_a(Hash) }
          expect(requests.size).to be_in [ 1, 2 ]
        end
      end

      it 'creates student PEs as the AlgorithmStudentClueCalculations arrive' do
        expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas).thrice do |reqs|
          reqs.each { |request| expect(request).to be_a(Hash) }
          expect(reqs.size).to be_in [ 1, 2 ]
        end

        expect { subject.process }.not_to change { StudentPe.count }

        expect do
          Services::UpdateClueCalculations::Service.new.process(
            clue_calculation_updates: [
              {
                calculation_uuid: @scc_1.uuid,
                algorithm_name: @clue_algorithm_name,
                clue_data: {
                  minimum: 0,
                  most_likely: 0.25,
                  maximum: 0.5,
                  is_real: true,
                  ecosystem_uuid: SecureRandom.uuid
                }
              }
            ]
          )
        end.to(
          change do
            AlgorithmStudentClueCalculation.where(algorithm_name: @clue_algorithm_name).count
          end.by(1)
        )
        expect { subject.process }.to change { StudentPe.count }.by(5)

        student_pes = StudentPe.order(created_at: :desc).limit(5)

        valid_exercise_uuids = ExercisePool.where(
          book_container_uuid: @scc_1.book_container_uuid
        ).flat_map(&:exercise_uuids)
        expect(student_pes.map(&:exercise_uuid) - valid_exercise_uuids).to be_empty

        expect do
          Services::UpdateClueCalculations::Service.new.process(
            clue_calculation_updates: [
              {
                calculation_uuid: @scc_2.uuid,
                algorithm_name: @clue_algorithm_name,
                clue_data: {
                  minimum: 0,
                  most_likely: 0,
                  maximum: 0.25,
                  is_real: true,
                  ecosystem_uuid: SecureRandom.uuid
                }
              },
              {
                calculation_uuid: @scc_3.uuid,
                algorithm_name: @clue_algorithm_name,
                clue_data: {
                  minimum: 0.25,
                  most_likely: 0.5,
                  maximum: 0.75,
                  is_real: true,
                  ecosystem_uuid: SecureRandom.uuid
                }
              }
            ]
          )
        end.to(
          change do
            AlgorithmStudentClueCalculation.where(algorithm_name: @clue_algorithm_name).count
          end.by(2)
        )
        expect { subject.process }.not_to change { StudentPe.count }

        valid_exercise_uuids = ExercisePool.where(
          book_container_uuid: [ @scc_1, @scc_2, @scc_3 ].map(&:book_container_uuid)
        ).flat_map(&:exercise_uuids)
        expect(student_pes.reload.map(&:exercise_uuid) - valid_exercise_uuids).to be_empty

        expect do
          Services::UpdateClueCalculations::Service.new.process(
            clue_calculation_updates: [
              {
                calculation_uuid: @scc_4.uuid,
                algorithm_name: @clue_algorithm_name,
                clue_data: {
                  minimum: 0.5,
                  most_likely: 0.75,
                  maximum: 1,
                  is_real: true,
                  ecosystem_uuid: SecureRandom.uuid
                }
              },
              {
                calculation_uuid: @scc_5.uuid,
                algorithm_name: @clue_algorithm_name,
                clue_data: {
                  minimum: 0.75,
                  most_likely: 1,
                  maximum: 1,
                  is_real: true,
                  ecosystem_uuid: SecureRandom.uuid
                }
              }
            ]
          )
        end.to(
          change do
            AlgorithmStudentClueCalculation.where(algorithm_name: @clue_algorithm_name).count
          end.by(2)
        )
        expect { subject.process }.not_to change { StudentPe.count }

        valid_exercise_uuids = ExercisePool.where(
          book_container_uuid: [ @scc_1, @scc_2, @scc_3, @scc_4, @scc_5 ].map(&:book_container_uuid)
        ).flat_map(&:exercise_uuids)
        expect(student_pes.reload.map(&:exercise_uuid) - valid_exercise_uuids).to be_empty
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::UploadAssignmentExercises::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments' do
    it 'does not create any SPEs or PEs' do
      expect { subject.process }.to  not_change { AssignmentSpe.count }
                                .and not_change { AssignmentPe.count  }
    end
  end

  context 'with existing Ecosystems, Course, ExercisePools, Exercises, BookContainerMappings,' +
          ' Assignments, AssignedExercises, ExerciseCalculations' +
          ' and AlgorithmExerciseCalculations' do
    before(:all) do
      DatabaseCleaner.start

      ecosystem_1 = FactoryGirl.create :ecosystem
      ecosystem_2 = FactoryGirl.create :ecosystem

      course = FactoryGirl.create :course, ecosystem_uuid: ecosystem_2.uuid
      student = FactoryGirl.create :student, course: course

      @reading_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 10,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_1_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_1_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_1_old.book_container_uuid
      @reading_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 9,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @reading_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_2_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_2_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_2_old.book_container_uuid
      @reading_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 8,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_3_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_3_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_3_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_3_old.book_container_uuid
      @reading_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 7,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_4_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_4_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_4_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_4_old.book_container_uuid
      @reading_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      @reading_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 6,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['reading']
      )
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_1.uuid,
                         to_ecosystem_uuid: ecosystem_2.uuid,
                         from_book_container_uuid: @reading_pool_5_old.book_container_uuid,
                         to_book_container_uuid: @reading_pool_5_new.book_container_uuid
      FactoryGirl.create :book_container_mapping,
                         from_ecosystem_uuid: ecosystem_2.uuid,
                         to_ecosystem_uuid: ecosystem_1.uuid,
                         from_book_container_uuid: @reading_pool_5_new.book_container_uuid,
                         to_book_container_uuid: @reading_pool_5_old.book_container_uuid

      @homework_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 5,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      @homework_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_1_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      @homework_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 4,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      @homework_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        exercise_uuids: @homework_pool_2_old.exercise_uuids,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      @homework_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_old.book_container_uuid
      )
      @homework_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 3,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      @homework_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_old.book_container_uuid
      )
      @homework_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 2,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      @homework_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_5_old.book_container_uuid
      )
      @homework_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        exercises_count: 1,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['homework'],
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      practice_pool_1_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_old.exercise_uuids + @homework_pool_1_old.exercise_uuids,
        book_container_uuid: @reading_pool_1_old.book_container_uuid
      )
      practice_pool_1_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_1_new.exercise_uuids + @homework_pool_1_new.exercise_uuids,
        book_container_uuid: @reading_pool_1_new.book_container_uuid
      )
      practice_pool_2_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_old.exercise_uuids + @homework_pool_2_old.exercise_uuids,
        book_container_uuid: @reading_pool_2_old.book_container_uuid
      )
      practice_pool_2_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_2_new.exercise_uuids + @homework_pool_2_new.exercise_uuids,
        book_container_uuid: @reading_pool_2_new.book_container_uuid
      )
      practice_pool_3_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_3_old.exercise_uuids + @homework_pool_3_old.exercise_uuids,
        book_container_uuid: @reading_pool_3_old.book_container_uuid
      )
      practice_pool_3_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_3_new.exercise_uuids + @homework_pool_3_new.exercise_uuids,
        book_container_uuid: @reading_pool_3_new.book_container_uuid
      )
      practice_pool_4_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_4_old.exercise_uuids + @homework_pool_4_old.exercise_uuids,
        book_container_uuid: @reading_pool_4_old.book_container_uuid
      )
      practice_pool_4_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_4_new.exercise_uuids + @homework_pool_4_new.exercise_uuids,
        book_container_uuid: @reading_pool_4_new.book_container_uuid
      )
      practice_pool_5_old = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_1.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_5_old.exercise_uuids + @homework_pool_5_old.exercise_uuids,
        book_container_uuid: @reading_pool_5_old.book_container_uuid
      )
      practice_pool_5_new = FactoryGirl.create(
        :exercise_pool,
        ecosystem_uuid: ecosystem_2.uuid,
        use_for_personalized_for_assignment_types: ['practice'],
        exercise_uuids: @reading_pool_5_new.exercise_uuids + @homework_pool_5_new.exercise_uuids,
        book_container_uuid: @reading_pool_5_new.book_container_uuid
      )

      old_exercise_uuids = [
        practice_pool_1_old,
        practice_pool_2_old,
        practice_pool_3_old,
        practice_pool_4_old,
        practice_pool_5_old
      ].flat_map(&:exercise_uuids)
      new_exercise_uuids = [
        practice_pool_1_new,
        practice_pool_2_new,
        practice_pool_3_new,
        practice_pool_4_new,
        practice_pool_5_new
      ].flat_map(&:exercise_uuids)
      new_exercise_uuids.each { |exercise_uuid| FactoryGirl.create :exercise, uuid: exercise_uuid }

      # EO - Expected Order (Instructor-Driven and Student-Driven in the expected order)
      # RO - Student-Driven in the reverse order

      # 0 SPEs, 0 PEs requested
      @reading_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_1.uuid,
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

      # 1 SPEs, 1 PEs requested; PE is filled
      # EO: SPE filled from reading 1
      # RO: SPE filled from reading 3
      @reading_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_2.uuid,
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

      # 2 SPEs, 2 PEs requested; PEs are filled
      # EO: 1-ago SPE filled from reading 2, 3-ago SPE filled as PE since no 3-ago reading
      # RO: Only 1 SPE filled as PE since the real PEs took 2 out of 3 available exercises
      @reading_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        ecosystem_uuid: ecosystem_2.uuid,
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

      # 2 SPEs, 1 PE requested; PE cannot be filled
      # EO: No exercises available to fill anything
      # RO: Only 1-ago SPE can be filled from homework 2
      @homework_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_1.uuid,
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

      # 1 SPE, 1 PE requested; PE cannot be filled
      # EO: Only 1-ago SPE can be filled from homework 1
      # RO: Only 1-ago SPE can be filled from homework 3
      @homework_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_2.uuid,
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

      # 2 SPEs, 1 PE requested; PE cannot be filled
      # EO: Only 1-ago SPE can be filled from homework 2
      # RO: No exercises available to fill anything
      @homework_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        ecosystem_uuid: ecosystem_2.uuid,
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

      exercise_calculation_1 = FactoryGirl.create(
        :exercise_calculation,
        ecosystem: ecosystem_1,
        student: student
      )
      @algorithm_exercise_calculation_1 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_1,
        exercise_uuids: old_exercise_uuids.shuffle
      )

      exercise_calculation_2 = FactoryGirl.create(
        :exercise_calculation,
        ecosystem: ecosystem_2,
        student: student
      )
      @algorithm_exercise_calculation_2 = FactoryGirl.create(
        :algorithm_exercise_calculation,
        exercise_calculation: exercise_calculation_2,
        exercise_uuids: new_exercise_uuids.shuffle
      )
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:expected_assignment_pes) do
      [
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
          assignment_uuid: @reading_2.uuid,
          exercise_pool: @reading_pool_3_new.exercise_uuids +
                         @reading_pool_4_new.exercise_uuids -
                         @reading_2.assigned_exercise_uuids,
          exercise_count: 1
        },
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
          assignment_uuid: @reading_3.uuid,
          exercise_pool: @reading_pool_4_new.exercise_uuids +
                         @reading_pool_5_new.exercise_uuids -
                         @reading_3.assigned_exercise_uuids,
          exercise_count: 2
        },
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_1,
          assignment_uuid: @homework_1.uuid,
          exercise_pool: [],
          exercise_count: 0
        },
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
          assignment_uuid: @homework_2.uuid,
          exercise_pool: [],
          exercise_count: 0
        },
        {
          algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
          assignment_uuid: @homework_3.uuid,
          exercise_pool: [],
          exercise_count: 0
        }
      ]
    end

    let(:assignment_pes_by_assignment_uuid) do
      expected_assignment_pes.index_by { |calc| calc[:assignment_uuid] }
    end

    let(:assignment_spes_by_assignment_uuid_and_history_type) do
      Hash.new { |hash, key| hash[key] = {} }.tap do |hash|
        expected_assignment_spes.each do |calc|
          hash[calc[:assignment_uuid]][calc[:history_type]] = calc
        end
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
          FactoryGirl.create :response, trial_uuid: assigned_exercise.uuid
        end
      end
    end

    let(:expected_num_spes) do
      expected_assignment_spes.map { |calc| calc[:exercise_count] }.reduce(0, :+)
    end
    let(:expected_num_spe_records) do
      expected_assignment_spes.map { |calc| [calc[:exercise_count], 1].max }.reduce(0, :+)
    end
    let(:expected_num_pes) do
      expected_assignment_pes.map { |calc| calc[:exercise_count] }.reduce(0, :+)
    end
    let(:expected_num_pe_records) do
      expected_assignment_pes.map { |calc| [calc[:exercise_count], 1].max }.reduce(0, :+)
    end

    before do
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes).with(
        [a_kind_of(Hash)] * expected_assignment_pes.size
      )
      expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes).with(
        [a_kind_of(Hash)] * expected_assignment_spes.size
      )
    end

    context 'with assignments completed in the expected order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ]
      end

      let(:expected_assignment_spes) do
        [
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_2.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @reading_pool_1_new.exercise_uuids +
                           @reading_pool_2_new.exercise_uuids -
                           @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_2.uuid,
            history_type: 'student_driven',
            exercise_pool: @reading_pool_1_new.exercise_uuids +
                           @reading_pool_2_new.exercise_uuids -
                           @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @reading_pool_3_new.exercise_uuids +
                           @reading_pool_4_new.exercise_uuids +
                           @reading_pool_5_new.exercise_uuids -
                           @reading_3.assigned_exercise_uuids,
            exercise_count: 2
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            exercise_pool: @reading_pool_3_new.exercise_uuids +
                           @reading_pool_4_new.exercise_uuids +
                           @reading_pool_5_new.exercise_uuids -
                           @reading_3.assigned_exercise_uuids,
            exercise_count: 2
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_1,
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            exercise_pool: [],
            exercise_count: 0
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_1,
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            exercise_pool: [],
            exercise_count: 0
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_2.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @homework_pool_1_new.exercise_uuids +
                           @homework_pool_2_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_2.uuid,
            history_type: 'student_driven',
            exercise_pool: @homework_pool_1_new.exercise_uuids +
                           @homework_pool_2_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @homework_pool_3_new.exercise_uuids +
                           @homework_pool_4_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            exercise_pool: @homework_pool_3_new.exercise_uuids +
                           @homework_pool_4_new.exercise_uuids,
            exercise_count: 1
          }
        ]
      end

      it 'creates the correct numbers of Biglearn requests, SPEs and PEs from the correct pools' do
        expect { subject.process }
          .to  change { AssignmentSpe.count }.by(expected_num_spe_records)
          .and change { AssignmentSpe.where.not(exercise_uuid: nil).count }.by(expected_num_spes)
          .and change { AssignmentPe.count }.by(expected_num_pe_records)
          .and change { AssignmentPe.where.not(exercise_uuid: nil).count  }.by(expected_num_pes)

        expected_assignment_spes.each do |expected_assignment_spe|
          assignment_spes = AssignmentSpe.where(
            assignment_uuid: expected_assignment_spe[:assignment_uuid],
            history_type: expected_assignment_spe[:history_type]
          )

          if expected_assignment_spe[:exercise_count] == 0
            expect(assignment_spes.size).to eq 1

            assignment_spe = assignment_spes.first
            expect(assignment_spe.algorithm_exercise_calculation_uuid).to(
              eq expected_assignment_spe[:algorithm_exercise_calculation].uuid
            )
            expect(assignment_spe.exercise_uuid).to be_nil
          else
            expect(assignment_spes.size).to eq expected_assignment_spe[:exercise_count]

            assignment_spes.each do |assignment_spe|
              expect(assignment_spe.algorithm_exercise_calculation_uuid).to(
                eq expected_assignment_spe[:algorithm_exercise_calculation].uuid
              )
              expect(assignment_spe.exercise_uuid).to be_in expected_assignment_spe[:exercise_pool]
            end
          end
        end

        expected_assignment_pes.each do |expected_assignment_pe|
          assignment_pes = AssignmentPe.where(
            assignment_uuid: expected_assignment_pe[:assignment_uuid]
          )

          if expected_assignment_pe[:exercise_count] == 0
            expect(assignment_pes.size).to eq 1

            assignment_pe = assignment_pes.first
            expect(assignment_pe.algorithm_exercise_calculation_uuid).to(
              eq expected_assignment_pe[:algorithm_exercise_calculation].uuid
            )
            expect(assignment_pe.exercise_uuid).to be_nil
          else
            expect(assignment_pes.size).to eq expected_assignment_pe[:exercise_count]

            assignment_pes.each do |assignment_pe|
              expect(assignment_pe.algorithm_exercise_calculation_uuid).to(
                eq expected_assignment_pe[:algorithm_exercise_calculation].uuid
              )
              expect(assignment_pe.exercise_uuid).to be_in expected_assignment_pe[:exercise_pool]
            end
          end
        end
      end
    end

    context 'with assignments completed in the reverse order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ].reverse
      end

      let(:expected_assignment_spes) do
        [
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_2.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @reading_pool_1_new.exercise_uuids +
                           @reading_pool_2_new.exercise_uuids -
                           @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_2.uuid,
            history_type: 'student_driven',
            exercise_pool: @reading_pool_4_new.exercise_uuids +
                           @reading_pool_5_new.exercise_uuids -
                           @reading_2.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_3.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @reading_pool_3_new.exercise_uuids +
                           @reading_pool_4_new.exercise_uuids +
                           @reading_pool_5_new.exercise_uuids -
                           @reading_3.assigned_exercise_uuids,
            exercise_count: 2
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @reading_3.uuid,
            history_type: 'student_driven',
            exercise_pool: @reading_pool_4_new.exercise_uuids +
                           @reading_pool_5_new.exercise_uuids -
                           @reading_3.assigned_exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_1,
            assignment_uuid: @homework_1.uuid,
            history_type: 'instructor_driven',
            exercise_pool: [],
            exercise_count: 0
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_1,
            assignment_uuid: @homework_1.uuid,
            history_type: 'student_driven',
            exercise_pool: @homework_pool_3_old.exercise_uuids +
                           @homework_pool_4_old.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_2.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @homework_pool_1_new.exercise_uuids +
                           @homework_pool_2_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_2.uuid,
            history_type: 'student_driven',
            exercise_pool: @homework_pool_4_new.exercise_uuids +
                           @homework_pool_5_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_3.uuid,
            history_type: 'instructor_driven',
            exercise_pool: @homework_pool_3_new.exercise_uuids +
                           @homework_pool_4_new.exercise_uuids,
            exercise_count: 1
          },
          {
            algorithm_exercise_calculation: @algorithm_exercise_calculation_2,
            assignment_uuid: @homework_3.uuid,
            history_type: 'student_driven',
            exercise_pool: [],
            exercise_count: 0
          }
        ]
      end

      it 'creates the correct numbers of Biglearn requests, SPEs and PEs from the correct pools' do
        expect { subject.process }
          .to  change { AssignmentSpe.count }.by(expected_num_spe_records)
          .and change { AssignmentSpe.where.not(exercise_uuid: nil).count }.by(expected_num_spes)
          .and change { AssignmentPe.count }.by(expected_num_pe_records)
          .and change { AssignmentPe.where.not(exercise_uuid: nil).count  }.by(expected_num_pes)

        expected_assignment_spes.each do |expected_assignment_spe|
          assignment_spes = AssignmentSpe.where(
            assignment_uuid: expected_assignment_spe[:assignment_uuid],
            history_type: expected_assignment_spe[:history_type]
          )

          if expected_assignment_spe[:exercise_count] == 0
            expect(assignment_spes.size).to eq 1

            assignment_spe = assignment_spes.first
            expect(assignment_spe.algorithm_exercise_calculation_uuid).to(
              eq expected_assignment_spe[:algorithm_exercise_calculation].uuid
            )
            expect(assignment_spe.exercise_uuid).to be_nil
          else
            expect(assignment_spes.size).to eq expected_assignment_spe[:exercise_count]

            assignment_spes.each do |assignment_spe|
              expect(assignment_spe.algorithm_exercise_calculation_uuid).to(
                eq expected_assignment_spe[:algorithm_exercise_calculation].uuid
              )
              expect(assignment_spe.exercise_uuid).to be_in expected_assignment_spe[:exercise_pool]
            end
          end
        end

        expected_assignment_pes.each do |expected_assignment_pe|
          assignment_pes = AssignmentPe.where(
            assignment_uuid: expected_assignment_pe[:assignment_uuid]
          )

          if expected_assignment_pe[:exercise_count] == 0
            expect(assignment_pes.size).to eq 1

            assignment_pe = assignment_pes.first
            expect(assignment_pe.algorithm_exercise_calculation_uuid).to(
              eq expected_assignment_pe[:algorithm_exercise_calculation].uuid
            )
            expect(assignment_pe.exercise_uuid).to be_nil
          else
            expect(assignment_pes.size).to eq expected_assignment_pe[:exercise_count]

            assignment_pes.each do |assignment_pe|
              expect(assignment_pe.algorithm_exercise_calculation_uuid).to(
                eq expected_assignment_pe[:algorithm_exercise_calculation].uuid
              )
              expect(assignment_pe.exercise_uuid).to be_in expected_assignment_pe[:exercise_pool]
            end
          end
        end
      end
    end
  end
end

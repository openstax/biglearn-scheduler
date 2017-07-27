require 'rails_helper'

RSpec.describe Services::UpdateStudentHistory::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments' do
    it 'does not update anything' do
      expect { subject.process }.to  not_change { Assignment.count }
                                .and not_change { AssignmentSpe.count  }
    end
  end

  context 'with existing Students, Assignments, AssignedExercises, Responses and AssignmentSpes' do
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

      current_time = Time.current

      @reading_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        opens_at: current_time.yesterday - 5.days,
        due_at: current_time.tomorrow,
        feedback_at: current_time.yesterday - 5.days,
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

      @reading_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        opens_at: current_time.yesterday - 3.days,
        due_at: current_time.tomorrow + 2.days,
        feedback_at: current_time.yesterday - 3.days,
        ecosystem_uuid: ecosystem_2.uuid,
        assigned_exercise_uuids: @reading_pool_3_new.exercise_uuids.sample(5) +
                                 @reading_pool_4_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [
          @reading_pool_3_new.book_container_uuid, @reading_pool_4_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 2,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      @reading_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'reading',
        opens_at: current_time.yesterday - 1.day,
        due_at: current_time.tomorrow + 4.days,
        feedback_at: current_time.yesterday - 1.day,
        ecosystem_uuid: ecosystem_2.uuid,
        assigned_exercise_uuids: @reading_pool_4_new.exercise_uuids.sample(5) +
                                 @reading_pool_5_new.exercise_uuids.sample(5),
        assigned_book_container_uuids: [
          @reading_pool_4_new.book_container_uuid, @reading_pool_5_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 2,
        pes_are_assigned: false
      )

      @homework_1 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        opens_at: current_time.yesterday - 4.days,
        due_at: current_time.tomorrow + 1.day,
        feedback_at: current_time.yesterday - 4.days,
        ecosystem_uuid: ecosystem_1.uuid,
        assigned_exercise_uuids: @homework_pool_1_old.exercise_uuids +
                                 @homework_pool_2_old.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_1_old.book_container_uuid, @homework_pool_2_old.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      @homework_2 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        opens_at: current_time.yesterday - 2.days,
        due_at: current_time.tomorrow + 3.days,
        feedback_at: current_time.yesterday - 2.days,
        ecosystem_uuid: ecosystem_2.uuid,
        assigned_exercise_uuids: @homework_pool_3_new.exercise_uuids +
                                 @homework_pool_4_new.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_3_new.book_container_uuid, @homework_pool_4_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 2,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      @homework_3 = FactoryGirl.create(
        :assignment,
        course_uuid: course.uuid,
        student_uuid: student.uuid,
        assignment_type: 'homework',
        opens_at: current_time.yesterday,
        due_at: current_time.tomorrow + 5.days,
        feedback_at: current_time.tomorrow + 5.days,
        ecosystem_uuid: ecosystem_2.uuid,
        assigned_exercise_uuids: @homework_pool_4_new.exercise_uuids +
                                 @homework_pool_5_new.exercise_uuids,
        assigned_book_container_uuids: [
          @homework_pool_4_new.book_container_uuid, @homework_pool_5_new.book_container_uuid
        ],
        goal_num_tutor_assigned_spes: 3,
        spes_are_assigned: false,
        goal_num_tutor_assigned_pes: 1,
        pes_are_assigned: false
      )

      [ @reading_1, @homework_1 ].each do |assignment|
        FactoryGirl.create :assignment_spe, assignment: assignment
      end
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:all_assignment_uuids)     do
      [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ].map(&:uuid)
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
          FactoryGirl.create :response, trial_uuid: assigned_exercise.uuid,
                                        used_in_student_history: false
        end
      end
    end

    context 'with assignments completed in the expected order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ]
      end

      it 'marks the responses as used in the student history' do
        expect { subject.process }.to(
          change do
            ordered_responses.map(&:reload).count(&:used_in_student_history)
          end.from(0).to(ordered_responses.count)
        )
      end

      it 'adds the assignments to the student history in the correct order' do
        expect { subject.process }.to  not_change { Assignment.count }
                                  .and change     { AssignmentSpe.count }.by(-2)

        student_history_assignments = Assignment
          .where(uuid: all_assignment_uuids)
          .where.not(student_history_at: nil)
          .order(:student_history_at)

        expect(student_history_assignments).to eq ordered_assignments
      end
    end

    context 'with assignments completed in the reverse order' do
      let(:ordered_assignments) do
        [ @reading_1, @homework_1, @reading_2, @homework_2, @reading_3, @homework_3 ].reverse
      end

      it 'marks the responses as used in the student history' do
        expect { subject.process }.to(
          change do
            ordered_responses.map(&:reload).count(&:used_in_student_history)
          end.from(0).to(ordered_responses.count)
        )
      end

      it 'adds the assignments to the student history in the correct order' do
        expect { subject.process }.to  not_change { Assignment.count }
                                  .and change     { AssignmentSpe.count }.by(-2)

        student_history_assignments = Assignment
          .where(uuid: all_assignment_uuids)
          .where.not(student_history_at: nil)
          .order(:student_history_at)

        expect(student_history_assignments).to eq ordered_assignments
      end
    end

    context 'with incomplete assignments' do
      let(:ordered_assignments) do
        [ @reading_2, @homework_2, @reading_3, @homework_3 ]
      end

      it 'marks the responses as used in the student history' do
        expect { subject.process }.to(
          change do
            ordered_responses.map(&:reload).count(&:used_in_student_history)
          end.from(0).to(ordered_responses.count)
        )
      end

      it 'adds the assignments to the student history in the correct order' do
        expect { subject.process }.to  not_change { Assignment.count }
                                  .and change { AssignmentSpe.count }.by(-2)

        student_history_assignments = Assignment
          .where(uuid: all_assignment_uuids)
          .where.not(student_history_at: nil)
          .order(:student_history_at)

        expect(student_history_assignments).to eq ordered_assignments
      end
    end

    context 'with incomplete past-due assignments' do
      let(:ordered_assignments) do
        [ @reading_2, @homework_2, @reading_3, @homework_3 ]
      end

      let(:current_time)        { Time.current }

      before do
        @reading_1.update_attribute :due_at, current_time.yesterday

        @homework_1.update_attribute :due_at, current_time.yesterday
      end

      it 'marks the responses as used in the student history' do
        expect { subject.process }.to(
          change do
            ordered_responses.map(&:reload).count(&:used_in_student_history)
          end.from(0).to(ordered_responses.count)
        )
      end

      it 'adds the assignments to the student history in the correct order' do
        expect { subject.process }.to  not_change { Assignment.count }
                                  .and change     { AssignmentSpe.count }.by(-2)

        student_history_assignments = Assignment
          .where(uuid: all_assignment_uuids)
          .where.not(student_history_at: nil)
          .order(:student_history_at)

        expect(student_history_assignments).to eq [ @reading_1, @homework_1 ] + ordered_assignments
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::UpdatePracticeWorstAreasExercises::Service, type: :service do
  subject { described_class.new }

  context 'with no Assignments' do
    it 'does not update the exercises' do
      expect(OpenStax::Biglearn::Api).to receive(:update_practice_worst_areas).with([])

      expect { subject.process }.to  not_change { Student.count   }
                                .and not_change { StudentPe.count }
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

      FactoryGirl.create :student_clue,
                         student_uuid: @student.uuid,
                         book_container_uuid: @practice_pool_1_new.book_container_uuid,
                         value: 0.25
      FactoryGirl.create :student_clue,
                         student_uuid: @student.uuid,
                         book_container_uuid: @practice_pool_2_new.book_container_uuid,
                         value: 0
      FactoryGirl.create :student_clue,
                         student_uuid: @student.uuid,
                         book_container_uuid: @practice_pool_3_new.book_container_uuid,
                         value: 0.5
      FactoryGirl.create :student_clue,
                         student_uuid: @student.uuid,
                         book_container_uuid: @practice_pool_4_new.book_container_uuid,
                         value: 0.75
      FactoryGirl.create :student_clue,
                         student_uuid: @student.uuid,
                         book_container_uuid: @practice_pool_5_new.book_container_uuid,
                         value: 1
    end

    after(:all)  { DatabaseCleaner.clean }

    let(:expected_pwa_requests) do
      [
        {
          student_uuid: @student.uuid,
          exercise_uuids: match_array(
            # This should match the counts in the get_worst_clue_pes_map method for 5 CLUes
            [
              be_in(@practice_pool_1_new.exercise_uuids),
              be_in(@practice_pool_2_new.exercise_uuids),
              be_in(@practice_pool_3_new.exercise_uuids),
              be_in(@practice_pool_4_new.exercise_uuids),
              be_in(@practice_pool_5_new.exercise_uuids)
            ]
          )
        }
      ]
    end

    it 'assigns the correct numbers of exercises from the correct pools' do
      expect(OpenStax::Biglearn::Api).to(
        receive(:update_practice_worst_areas) do |requests|
          expect(requests).to match_array expected_pwa_requests
        end
      )

      expect { subject.process }.to  not_change { Student.count   }
                                .and change     { StudentPe.count }.by(5)

      new_student_pes = StudentPe.order(:created_at).last(5)
        book_container_uuids = new_student_pes.map { |student_pe| student_pe.book_container_uuid }
        expect(book_container_uuids).to match_array(
          [
            @practice_pool_1_new.book_container_uuid,
            @practice_pool_2_new.book_container_uuid,
            @practice_pool_3_new.book_container_uuid,
            @practice_pool_4_new.book_container_uuid,
            @practice_pool_5_new.book_container_uuid
          ]
        )
        exercise_uuids = new_student_pes.map { |student_pe| student_pe.exercise_uuid }
        exercise_uuids.each do |exercise_uuid|
          expect(exercise_uuid).to be_in(
            @practice_pool_1_new.exercise_uuids +
            @practice_pool_2_new.exercise_uuids +
            @practice_pool_3_new.exercise_uuids +
            @practice_pool_4_new.exercise_uuids +
            @practice_pool_5_new.exercise_uuids
          )
        end
    end

    context 'with some Assignments and some Practice exercises already assigned' do
      before(:all) do
        DatabaseCleaner.start

        # These assignments are taking all available exercises
        # Practice must come from @reading_pool_1_new
        # since only the first reading is past-due
        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'reading',
          ecosystem_uuid: @ecosystem_uuid_1,
          due_at: Time.now.yesterday,
          assigned_exercise_uuids: @reading_pool_1_old.exercise_uuids,
          assigned_book_container_uuids: [ @reading_pool_1_old.book_container_uuid ],
          goal_num_tutor_assigned_spes: 0,
          spes_are_assigned: false,
          goal_num_tutor_assigned_pes: 0,
          pes_are_assigned: false
        )

        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'reading',
          ecosystem_uuid: @ecosystem_uuid_2,
          due_at: Time.now.tomorrow,
          assigned_exercise_uuids: @reading_pool_2_old.exercise_uuids,
          assigned_book_container_uuids: [ @reading_pool_2_old.book_container_uuid ],
          goal_num_tutor_assigned_spes: 1,
          spes_are_assigned: false,
          goal_num_tutor_assigned_pes: 1,
          pes_are_assigned: false
        )

        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'reading',
          ecosystem_uuid: @ecosystem_uuid_2,
          due_at: Time.now.tomorrow + 1.day,
          assigned_exercise_uuids: @reading_pool_3_new.exercise_uuids +
                                   @reading_pool_4_new.exercise_uuids +
                                   @reading_pool_5_new.exercise_uuids,
          assigned_book_container_uuids: [
            @reading_pool_3_new.book_container_uuid,
            @reading_pool_4_new.book_container_uuid,
            @reading_pool_5_new.book_container_uuid
          ],
          goal_num_tutor_assigned_spes: 2,
          spes_are_assigned: false,
          goal_num_tutor_assigned_pes: 2,
          pes_are_assigned: false
        )

        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'homework',
          ecosystem_uuid: @ecosystem_uuid_1,
          due_at: Time.now.tomorrow + 2.days,
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

        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'homework',
          ecosystem_uuid: @ecosystem_uuid_2,
          due_at: Time.now.tomorrow + 3.days,
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

        FactoryGirl.create(
          :assignment,
          course_uuid: @course.uuid,
          student_uuid: @student.uuid,
          assignment_type: 'homework',
          ecosystem_uuid: @ecosystem_uuid_2,
          due_at: Time.now.tomorrow + 4.days,
          assigned_exercise_uuids: @homework_pool_4_new.exercise_uuids +
                                   @homework_pool_5_new.exercise_uuids,
          assigned_book_container_uuids: [
            @homework_pool_4_new.book_container_uuid, @homework_pool_5_new.book_container_uuid
          ],
          goal_num_tutor_assigned_spes: 2,
          spes_are_assigned: false,
          goal_num_tutor_assigned_pes: 2,
          pes_are_assigned: false
        )

        already_assigned_exercise_pools = [ @practice_pool_1_new, @practice_pool_2_new ]
        @num_already_assigned_exercises = already_assigned_exercise_pools.size
        # These exercises come from @practice_pool_1_new,
        # but they are filling other pool slots as well
        assigned_practice_exercise_uuids = @practice_pool_1_new.exercise_uuids.sample(
          @num_already_assigned_exercises
        )
        assigned_practice_exercise_uuids.each_with_index do |exercise_uuid, index|
          pool = already_assigned_exercise_pools[index]

          FactoryGirl.create :student_pe,
                             book_container_uuid: pool.book_container_uuid,
                             student_uuid: @student.uuid,
                             exercise_uuid: exercise_uuid
        end
      end

      after(:all)  { DatabaseCleaner.clean }

      let(:expected_pwa_requests) do
        [
          {
            student_uuid: @student.uuid,
            exercise_uuids: [ be_in(@practice_pool_1_new.exercise_uuids) ] * 5
          }
        ]
      end

      it 'assigns only the missing exercises from the correct pools' do
        expect(OpenStax::Biglearn::Api).to(
          receive(:update_practice_worst_areas) do |requests|
            expect(requests).to match_array expected_pwa_requests
          end
        )

        expect { subject.process }.to  not_change { Student.count   }
                                  .and change     { StudentPe.count }
                                                    .by(5 - @num_already_assigned_exercises)

        new_student_pes = StudentPe.order(:created_at).last(5 - @num_already_assigned_exercises)
        book_container_uuids = new_student_pes.map { |student_pe| student_pe.book_container_uuid }
        expect(book_container_uuids).to match_array(
          [
            @practice_pool_3_new.book_container_uuid,
            @practice_pool_4_new.book_container_uuid,
            @practice_pool_5_new.book_container_uuid
          ]
        )
        exercise_uuids = new_student_pes.map { |student_pe| student_pe.exercise_uuid }
        exercise_uuids.each do |exercise_uuid|
          expect(exercise_uuid).to be_in @practice_pool_1_new.exercise_uuids
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::FetchCourseEvents::Service, type: :service do
  subject { described_class.new }

  context 'with no events' do
    it 'does not modify any records' do
      expect { subject.process }.to  not_change { Course.count }
                                .and not_change { EcosystemPreparation.count }
                                .and not_change { BookContainerMapping.count }
                                .and not_change { CourseContainer.count }
                                .and not_change { Student.count }
                                .and not_change { Assignment.count }
                                .and not_change { AssignmentSpe.count }
                                .and not_change { AssignmentPe.count }
                                .and not_change { Response.count }
                                .and not_change { ResponseClue.count }
    end
  end

  context 'with an exiting course and course events' do
    let!(:course)                { FactoryGirl.create :course, sequence_number: 0 }

    let(:sequence_number)        { rand(10) + 1 }
    let(:event_uuid)             { SecureRandom.uuid }

    let(:course_event)           do
      {
        sequence_number: sequence_number,
        event_uuid: event_uuid,
        event_type: event_type,
        event_data: event_data
      }
    end

    let(:course_events)          { [ course_event ] }

    let(:course_events_response) do
      {
        request_uuid: SecureRandom.uuid,
        course_uuid: course.uuid,
        events: course_events,
        is_stopped_at_gap: false
      }
    end

    before                       do
      expect(OpenStax::Biglearn::Api).to receive(:fetch_course_events) do |requests|
        { requests.first => course_events_response }
      end
    end

    context 'prepare_course_ecosystem events' do
      let(:event_type)              { 'prepare_course_ecosystem' }
      let(:preparation_uuid)        { event_uuid }
      let(:ecosystem_uuid)          { SecureRandom.uuid }
      let(:num_bc_mappings)         { 3 }
      let(:book_container_mappings) do
        num_bc_mappings.times.map do
          {
            from_book_container_uuid: SecureRandom.uuid,
            to_book_container_uuid: SecureRandom.uuid
          }
        end
      end
      let(:exercise_mappings)       do
        5.times.map do
          {
            from_exercise_uuid: SecureRandom.uuid,
            to_book_container_uuid: SecureRandom.uuid
          }
        end
      end
      let(:ecosystem_map)           do
        {
          from_ecosystem_uuid: course.ecosystem_uuid,
          to_ecosystem_uuid: ecosystem_uuid,
          book_container_mappings: book_container_mappings,
          exercise_mappings: exercise_mappings
        }
      end
      let(:event_data)              do
        {
          preparation_uuid: preparation_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          ecosystem_uuid: ecosystem_uuid,
          ecosystem_map: ecosystem_map
        }
      end

      it 'creates only an EcosystemPreparation for the Course' do
        expect { subject.process }.to  not_change { Course.count }
                                  .and change     { EcosystemPreparation.count }.by(1)
                                  .and change     { BookContainerMapping.count }.by(num_bc_mappings)
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and not_change { Response.count }
                                  .and not_change { ResponseClue.count }
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }

        preparation = EcosystemPreparation.find_by uuid: preparation_uuid
        expect(preparation.course_uuid).to eq course.uuid
        expect(preparation.ecosystem_uuid).to eq ecosystem_uuid
      end
    end

    context 'update_course_ecosystem events' do
      let!(:preparation)       { FactoryGirl.create :ecosystem_preparation }

      let(:event_type)         { 'update_course_ecosystem' }
      let(:event_data)         do
        {
          request_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          preparation_uuid: preparation.uuid
        }
      end

      let(:num_response_clues) { rand(10) }
      let!(:response_clues)    do
        num_response_clues.times.map do
          FactoryGirl.create :response_clue, course_uuid: course.uuid
        end
      end

      it "updates the Course's ecosystem_uuid" do
        new_ecosystem_uuid = preparation.ecosystem_uuid

        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and not_change { Response.count }
                                  .and change     { ResponseClue.count }.by(-num_response_clues)
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and change     { course.ecosystem_uuid }.to(new_ecosystem_uuid)
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }
      end
    end

    context 'update_roster events' do
      let(:event_type)                     { 'update_roster' }
      let(:num_active_course_containers)   { 2 }
      let(:num_archived_course_containers) { 2 }
      let(:course_containers)              do
        num_active_course_containers.times.map do
          {
            container_uuid: SecureRandom.uuid,
            parent_container_uuid: course.uuid,
            is_archived: false
          }
        end + num_archived_course_containers.times.map do
          {
            container_uuid: SecureRandom.uuid,
            parent_container_uuid: course.uuid,
            is_archived: true
          }
        end
      end
      let(:num_students_per_container) { 5 }
      let(:students)                   do
        course_containers.flat_map do |course_container|
          num_students_per_container.times.map do
            {
              student_uuid: SecureRandom.uuid,
              container_uuid: course_container.fetch(:container_uuid)
            }
          end
        end
      end
      let(:event_data)                 do
        {
          request_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          course_containers: course_containers,
          students: students
        }
      end

      it 'creates or updates CourseContainers and Students for the Course' do
        num_containers = num_active_course_containers + num_archived_course_containers
        num_students = num_containers * num_students_per_container

        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and change     { CourseContainer.count }.by(num_containers)
                                  .and change     { Student.count }.by(num_students)
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and not_change { Response.count }
                                  .and not_change { ResponseClue.count }
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }
      end
    end

    context 'update_globally_excluded_exercises events' do
      let(:event_type)                        { 'update_globally_excluded_exercises' }
      let(:num_excluded_exercise_uuids)       { 5 }
      let(:excluded_exercise_uuids)           do
        num_excluded_exercise_uuids.times.map { SecureRandom.uuid }
      end
      let(:exercise_uuid_exclusions)          do
        excluded_exercise_uuids.map { |uuid| { exercise_uuid: uuid } }
      end
      let(:num_excluded_exercise_group_uuids) { 5 }
      let(:excluded_exercise_group_uuids)     do
        num_excluded_exercise_group_uuids.times.map { SecureRandom.uuid }
      end
      let(:exercise_group_uuid_exclusions)    do
        excluded_exercise_group_uuids.map { |uuid| { exercise_group_uuid: uuid } }
      end
      let(:exclusions)                        do
        exercise_uuid_exclusions + exercise_group_uuid_exclusions
      end
      let(:event_data)                        do
        {
          request_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          exclusions: exclusions
        }
      end

      it "updates the Course's global exclusions" do
        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and not_change { Response.count }
                                  .and not_change { ResponseClue.count }
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and change     { course.global_excluded_exercise_uuids }
                                  .and change     { course.global_excluded_exercise_group_uuids }

        expect(course.global_excluded_exercise_uuids).to match_array excluded_exercise_uuids
        expect(course.global_excluded_exercise_group_uuids).to(
          match_array excluded_exercise_group_uuids
        )
      end
    end

    context 'update_course_excluded_exercises events' do
      let(:event_type) { 'update_course_excluded_exercises' }
      let(:num_excluded_exercise_uuids)       { 5 }
      let(:excluded_exercise_uuids)           do
        num_excluded_exercise_uuids.times.map { SecureRandom.uuid }
      end
      let(:exercise_uuid_exclusions)          do
        excluded_exercise_uuids.map { |uuid| { exercise_uuid: uuid } }
      end
      let(:num_excluded_exercise_group_uuids) { 5 }
      let(:excluded_exercise_group_uuids)     do
        num_excluded_exercise_group_uuids.times.map { SecureRandom.uuid }
      end
      let(:exercise_group_uuid_exclusions)    do
        excluded_exercise_group_uuids.map { |uuid| { exercise_group_uuid: uuid } }
      end
      let(:exclusions)                        do
        exercise_uuid_exclusions + exercise_group_uuid_exclusions
      end
      let(:event_data)                        do
        {
          request_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          exclusions: exclusions
        }
      end

      it "updates the Course's course exclusions" do
        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and not_change { Response.count }
                                  .and not_change { ResponseClue.count }
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and change     { course.course_excluded_exercise_uuids }
                                  .and change     { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }

        expect(course.course_excluded_exercise_uuids).to match_array excluded_exercise_uuids
        expect(course.course_excluded_exercise_group_uuids).to(
          match_array excluded_exercise_group_uuids
        )
      end
    end

    context 'create_update_assignment events' do
      let(:event_type)                        { 'create_update_assignment' }
      let(:assignment_uuid)                   { SecureRandom.uuid }
      let(:is_deleted)                        { [true, false].sample }
      let(:ecosystem_uuid)                    { SecureRandom.uuid }
      let(:student_uuid)                      { SecureRandom.uuid }
      let(:assignment_type)                   do
        ['reading', 'homework', 'practice', 'concept-coach'].sample
      end
      let(:num_assigned_book_container_uuids) { 3 }
      let(:assigned_book_container_uuids)     do
        num_assigned_book_container_uuids.times.map { SecureRandom.uuid }
      end
      let(:goal_num_tutor_assigned_spes)      { rand 5 }
      let(:spes_are_assigned)                 { [true, false].sample }
      let(:goal_num_tutor_assigned_pes)       { rand 2 }
      let(:pes_are_assigned)                  { [true, false].sample }
      let(:num_assigned_exercises)            { 10 }
      let(:assigned_exercises)                do
        num_assigned_exercises.times.map do
          {
            trial_uuid: SecureRandom.uuid,
            exercise_uuid: SecureRandom.uuid,
            is_spe: [true, false].sample,
            is_pe: [true, false].sample
          }
        end
      end
      let(:event_data)                        do
        {
          request_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          assignment_uuid: assignment_uuid,
          is_deleted: is_deleted,
          ecosystem_uuid: ecosystem_uuid,
          student_uuid: student_uuid,
          assignment_type: assignment_type,
          exclusion_info: {
            opens_at: DateTime.now.yesterday.utc.iso8601,
            due_at: DateTime.now.tomorrow.utc.iso8601
          },
          assigned_book_container_uuids: assigned_book_container_uuids,
          goal_num_tutor_assigned_spes: goal_num_tutor_assigned_spes,
          spes_are_assigned: spes_are_assigned,
          goal_num_tutor_assigned_pes: goal_num_tutor_assigned_pes,
          pes_are_assigned: pes_are_assigned,
          assigned_exercises: assigned_exercises
        }
      end

      let!(:other_assignment)      do
        FactoryGirl.create :assignment, student_uuid: student_uuid,
                                        goal_num_tutor_assigned_spes: num_assigned_exercises,
                                        spes_are_assigned: true,
                                        goal_num_tutor_assigned_pes: num_assigned_exercises,
                                        pes_are_assigned: true
      end
      let!(:other_assignment_spes) do
        assigned_exercises.map do |assigned_exercise|
          FactoryGirl.create :assignment_spe, assignment_uuid: other_assignment.uuid,
                                              student_uuid: student_uuid,
                                              exercise_uuid: assigned_exercise.fetch(:exercise_uuid)
        end
      end
      let!(:other_assignment_pes) do
        assigned_exercises.map do |assigned_exercise|
          FactoryGirl.create :assignment_pe, assignment_uuid: other_assignment.uuid,
                                             student_uuid: student_uuid,
                                             exercise_uuid: assigned_exercise.fetch(:exercise_uuid)
        end
      end

      it 'creates an Assignment for the Course' do
        assigned_exercise_uuids = assigned_exercises.map { |ex| ex.fetch(:exercise_uuid) }

        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and change     { Assignment.count }.by(1)
                                  .and(change     do
                                    AssignmentSpe.count
                                  end.by(-num_assigned_exercises))
                                  .and(change     do
                                    AssignmentPe.count
                                  end.by(-num_assigned_exercises))
                                  .and not_change { ResponseClue.count }
                                  .and(change     do
                                    other_assignment.reload.spes_are_assigned
                                  end.from(true).to(false))
                                  .and(change     do
                                    other_assignment.pes_are_assigned
                                  end.from(true).to(false))
                                  .and not_change { Response.count }
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }

        assignment = Assignment.find_by uuid: assignment_uuid
        expect(assignment.course_uuid).to eq course.uuid
        expect(assignment.ecosystem_uuid).to eq ecosystem_uuid
        expect(assignment.student_uuid).to eq student_uuid
        expect(assignment.assignment_type).to eq assignment_type
        expect(assignment.assigned_book_container_uuids).to eq assigned_book_container_uuids
        expect(assignment.assigned_exercise_uuids).to eq assigned_exercise_uuids

        expect(assignment.goal_num_tutor_assigned_spes).to eq goal_num_tutor_assigned_spes
        expect(assignment.spes_are_assigned).to eq spes_are_assigned
        expect(assignment.goal_num_tutor_assigned_pes).to eq goal_num_tutor_assigned_pes
        expect(assignment.pes_are_assigned).to eq pes_are_assigned
      end
    end

    context 'record_response events' do
      let(:event_type)     { 'record_response' }
      let(:trial_uuid)     { SecureRandom.uuid }
      let(:student_uuid)   { SecureRandom.uuid }
      let(:exercise_uuid)  { SecureRandom.uuid }
      let(:is_correct)     { [true, false].sample }
      let(:responded_at)   { Time.now.utc.iso8601 }
      let(:event_data)     do
        {
          response_uuid: event_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          trial_uuid: trial_uuid,
          student_uuid: student_uuid,
          exercise_uuid: exercise_uuid,
          is_correct: is_correct,
          responded_at: responded_at
        }
      end

      let!(:response_clue) { FactoryGirl.create :response_clue, uuid: trial_uuid }

      it 'creates a Response for the Course' do
        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignmentSpe.count }
                                  .and not_change { AssignmentPe.count }
                                  .and change     { Response.count }.by(1)
                                  .and change     { ResponseClue.count }.by(-1)
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }

        response = Response.find_by uuid: trial_uuid
        expect(response.student_uuid).to eq student_uuid
        expect(response.exercise_uuid).to eq exercise_uuid
        expect(response.is_correct).to eq is_correct
      end
    end
  end
end

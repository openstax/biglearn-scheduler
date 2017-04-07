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
                                .and not_change { AssignedExercise.count }
                                .and not_change { AssignmentSpeCalculation.count }
                                .and not_change { AssignmentPeCalculation.count }
                                .and not_change { AssignmentSpeCalculationExercise.count }
                                .and not_change { AssignmentPeCalculationExercise.count }
                                .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                .and not_change { AlgorithmAssignmentPeCalculation.count }
                                .and not_change { Response.count }
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
      let(:event_type)                { 'prepare_course_ecosystem' }
      let(:preparation_uuid)          { event_uuid }
      let(:ecosystem_uuid)            { SecureRandom.uuid }
      let(:num_bc_mappings)           { 3 }
      let(:from_book_container_uuids) { num_bc_mappings.times.map { SecureRandom.uuid } }
      let(:to_book_container_uuids)   { num_bc_mappings.times.map { SecureRandom.uuid } }
      let(:book_container_mappings)   do
        num_bc_mappings.times.map do |index|
          {
            from_book_container_uuid: from_book_container_uuids[index],
            to_book_container_uuid: to_book_container_uuids[index]
          }
        end
      end
      let(:exercise_mappings)         do
        5.times.map do
          {
            from_exercise_uuid: SecureRandom.uuid,
            to_book_container_uuid: SecureRandom.uuid
          }
        end
      end
      let(:ecosystem_map)             do
        {
          from_ecosystem_uuid: course.ecosystem_uuid,
          to_ecosystem_uuid: ecosystem_uuid,
          book_container_mappings: book_container_mappings,
          exercise_mappings: exercise_mappings
        }
      end
      let(:event_data)                do
        {
          preparation_uuid: preparation_uuid,
          course_uuid: course.uuid,
          sequence_number: sequence_number,
          ecosystem_uuid: ecosystem_uuid,
          ecosystem_map: ecosystem_map
        }
      end

      context 'with no preexisting BookContainerMappings' do
        it 'creates an EcosystemPreparation, given BookContainerMappings' +
           ' and reverse BookContainerMappings for the Course' do
          expect { subject.process }.to  not_change { Course.count }
                                    .and change     { EcosystemPreparation.count }.by(1)
                                    .and(change     do
                                      BookContainerMapping.count
                                    end.by(2 * num_bc_mappings))
                                    .and not_change { CourseContainer.count }
                                    .and not_change { Student.count }
                                    .and not_change { Assignment.count }
                                    .and not_change { AssignedExercise.count }
                                    .and not_change { AssignmentSpeCalculation.count }
                                    .and not_change { AssignmentPeCalculation.count }
                                    .and not_change { AssignmentSpeCalculationExercise.count }
                                    .and not_change { AssignmentPeCalculationExercise.count }
                                    .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                    .and not_change { AlgorithmAssignmentPeCalculation.count }
                                    .and not_change { Response.count }
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

      context 'with preexisting BookContainerMappings' do
        let!(:chainable_book_container_mappings) do
          chainable_from_ecosystem_uuid = SecureRandom.uuid
          chainable_to_ecosystem_uuid = SecureRandom.uuid

          book_container_mappings.flat_map do |bcm|
            [
              FactoryGirl.create(:book_container_mapping,
                                 from_ecosystem_uuid: chainable_from_ecosystem_uuid,
                                 to_ecosystem_uuid: course.ecosystem_uuid,
                                 from_book_container_uuid: SecureRandom.uuid,
                                 to_book_container_uuid: bcm[:from_book_container_uuid]),

              FactoryGirl.create(:book_container_mapping,
                                 from_ecosystem_uuid: ecosystem_uuid,
                                 to_ecosystem_uuid: chainable_to_ecosystem_uuid,
                                 from_book_container_uuid: bcm[:to_book_container_uuid],
                                 to_book_container_uuid: SecureRandom.uuid)
            ]
          end
        end

        it 'creates an EcosystemPreparation, given BookContainerMappings,' +
           ' chain BookContainerMappings and reverse BookContainerMappings for the Course' do
          expect { subject.process }.to  not_change { Course.count }
                                    .and change     { EcosystemPreparation.count }.by(1)
                                    .and(change     do
                                      BookContainerMapping.count
                                    end.by(6 * num_bc_mappings))
                                    .and not_change { CourseContainer.count }
                                    .and not_change { Student.count }
                                    .and not_change { Assignment.count }
                                    .and not_change { AssignedExercise.count }
                                    .and not_change { AssignmentSpeCalculation.count }
                                    .and not_change { AssignmentPeCalculation.count }
                                    .and not_change { AssignmentSpeCalculationExercise.count }
                                    .and not_change { AssignmentPeCalculationExercise.count }
                                    .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                    .and not_change { AlgorithmAssignmentPeCalculation.count }
                                    .and not_change { Response.count }
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

      it "updates the Course's ecosystem_uuid" do
        new_ecosystem_uuid = preparation.ecosystem_uuid

        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignedExercise.count }
                                  .and not_change { AssignmentSpeCalculation.count }
                                  .and not_change { AssignmentPeCalculation.count }
                                  .and not_change { AssignmentSpeCalculationExercise.count }
                                  .and not_change { AssignmentPeCalculationExercise.count }
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and not_change { AlgorithmAssignmentPeCalculation.count }
                                  .and not_change { Response.count }
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
                                  .and not_change { AssignedExercise.count }
                                  .and not_change { AssignmentSpeCalculation.count }
                                  .and not_change { AssignmentPeCalculation.count }
                                  .and not_change { AssignmentSpeCalculationExercise.count }
                                  .and not_change { AssignmentPeCalculationExercise.count }
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and not_change { AlgorithmAssignmentPeCalculation.count }
                                  .and not_change { Response.count }
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
                                  .and not_change { AssignedExercise.count }
                                  .and not_change { AssignmentSpeCalculation.count }
                                  .and not_change { AssignmentPeCalculation.count }
                                  .and not_change { AssignmentSpeCalculationExercise.count }
                                  .and not_change { AssignmentPeCalculationExercise.count }
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and not_change { AlgorithmAssignmentPeCalculation.count }
                                  .and not_change { Response.count }
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
                                  .and not_change { AssignedExercise.count }
                                  .and not_change { AssignmentSpeCalculation.count }
                                  .and not_change { AssignmentPeCalculation.count }
                                  .and not_change { AssignmentSpeCalculationExercise.count }
                                  .and not_change { AssignmentPeCalculationExercise.count }
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and not_change { AlgorithmAssignmentPeCalculation.count }
                                  .and not_change { Response.count }
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
            opens_at: Time.now.yesterday.utc.iso8601,
            due_at: Time.now.tomorrow.utc.iso8601
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

      let!(:other_assignment_spe_calculation) do
        FactoryGirl.create :assignment_spe_calculation,
                           assignment_uuid: other_assignment.uuid,
                           student_uuid: student_uuid,
                           exercise_uuids: assigned_exercises.map { |ex| ex.fetch(:exercise_uuid) }
      end
      let!(:other_assignment_spe_calculation_exercises) do
        assigned_exercises.map do |assigned_exercise|
          FactoryGirl.create :assignment_spe_calculation_exercise,
                             assignment_spe_calculation_uuid: other_assignment_spe_calculation.uuid,
                             assignment_uuid: other_assignment.uuid,
                             student_uuid: student_uuid,
                             exercise_uuid: assigned_exercise.fetch(:exercise_uuid)
        end
      end
      let!(:other_assignment_algorithm_spe_calculation) do
        FactoryGirl.create :algorithm_assignment_spe_calculation,
                           assignment_spe_calculation_uuid: other_assignment_spe_calculation.uuid,
                           assignment_uuid: other_assignment.uuid,
                           student_uuid: student_uuid,
                           exercise_uuids: assigned_exercises.map { |ex| ex.fetch(:exercise_uuid) }
      end

      let!(:other_assignment_pe_calculation) do
        FactoryGirl.create :assignment_pe_calculation,
                           assignment_uuid: other_assignment.uuid,
                           student_uuid: student_uuid,
                           exercise_uuids: assigned_exercises.map { |ex| ex.fetch(:exercise_uuid) }
      end
      let!(:other_assignment_pe_calculation_exercises) do
        assigned_exercises.map do |assigned_exercise|
          FactoryGirl.create :assignment_pe_calculation_exercise,
                             assignment_pe_calculation_uuid: other_assignment_pe_calculation.uuid,
                             assignment_uuid: other_assignment.uuid,
                             student_uuid: student_uuid,
                             exercise_uuid: assigned_exercise.fetch(:exercise_uuid)
        end
      end
      let!(:other_assignment_algorithm_pe_calculation) do
        FactoryGirl.create :algorithm_assignment_pe_calculation,
                           assignment_pe_calculation_uuid: other_assignment_pe_calculation.uuid,
                           assignment_uuid: other_assignment.uuid,
                           student_uuid: student_uuid,
                           exercise_uuids: assigned_exercises.map { |ex| ex.fetch(:exercise_uuid) }
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
                                    AssignedExercise.count
                                  end.by(num_assigned_exercises))
                                  .and change { AssignmentSpeCalculation.count }.by(-1)
                                  .and change { AssignmentPeCalculation.count }.by(-1)
                                  .and(change do
                                    AssignmentSpeCalculationExercise.count
                                  end.by(-num_assigned_exercises))
                                  .and(change do
                                    AssignmentPeCalculationExercise.count
                                  end.by(-num_assigned_exercises))
                                  .and change { AlgorithmAssignmentSpeCalculation.count }.by(-1)
                                  .and change { AlgorithmAssignmentPeCalculation.count }.by(-1)
                                  .and not_change { Response.count }
                                  .and not_change { other_assignment.reload.spes_are_assigned }
                                  .and not_change { other_assignment.reload.pes_are_assigned }
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
        expect(assignment.assigned_exercise_uuids).to eq assigned_exercise_uuids.uniq

        expect(assignment.goal_num_tutor_assigned_spes).to eq goal_num_tutor_assigned_spes
        expect(assignment.spes_are_assigned).to eq spes_are_assigned
        expect(assignment.goal_num_tutor_assigned_pes).to eq goal_num_tutor_assigned_pes
        expect(assignment.pes_are_assigned).to eq pes_are_assigned
      end

      xcontext 'with an existing assignment with SPE/PE calculations and associated records' do
        it 'updates the existing assignment' do
        end
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

      it 'creates a Response for the Course' do
        expect { subject.process }.to  not_change { Course.count }
                                  .and not_change { EcosystemPreparation.count }
                                  .and not_change { BookContainerMapping.count }
                                  .and not_change { CourseContainer.count }
                                  .and not_change { Student.count }
                                  .and not_change { Assignment.count }
                                  .and not_change { AssignedExercise.count }
                                  .and not_change { AssignmentSpeCalculation.count }
                                  .and not_change { AssignmentPeCalculation.count }
                                  .and not_change { AssignmentSpeCalculationExercise.count }
                                  .and not_change { AssignmentPeCalculationExercise.count }
                                  .and not_change { AlgorithmAssignmentSpeCalculation.count }
                                  .and not_change { AlgorithmAssignmentPeCalculation.count }
                                  .and change     { Response.count }.by(1)
                                  .and(change     do
                                    course.reload.sequence_number
                                  end.from(0).to(sequence_number + 1))
                                  .and not_change { course.ecosystem_uuid }
                                  .and not_change { course.course_excluded_exercise_uuids }
                                  .and not_change { course.course_excluded_exercise_group_uuids }
                                  .and not_change { course.global_excluded_exercise_uuids }
                                  .and not_change { course.global_excluded_exercise_group_uuids }

        response = Response.find_by uuid: event_uuid
        expect(response.student_uuid).to eq student_uuid
        expect(response.exercise_uuid).to eq exercise_uuid
        expect(response.is_correct).to eq is_correct
        expect(response.used_in_latest_clue_calculations).to eq false
      end
    end
  end
end

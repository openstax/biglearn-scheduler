require 'rails_helper'

RSpec.describe CreateUpdateAssignmentSideEffectsJob, type: :job do
  subject do
    described_class.perform_later(
      assignment_uuids: [ new_assignment.uuid ],
      assigned_exercise_uuids: [
        assigned_exercise_1, assigned_exercise_2, assigned_exercise_3
      ].map(&:uuid),
      algorithm_exercise_calculation_uuids: [ algorithm_exercise_calculation.uuid ]
    )
  end

  let(:student_pe)                           { FactoryBot.create :student_pe }
  let(:algorithm_exercise_calculation)       { student_pe.algorithm_exercise_calculation }
  let(:exercise_calculation)                 { algorithm_exercise_calculation.exercise_calculation }
  let(:student)                              { exercise_calculation.student }
  let(:ecosystem)                            { exercise_calculation.ecosystem }
  let(:pe_assignment)                        do
    FactoryBot.create(
      :assignment,
      ecosystem: ecosystem,
      student: student,
      goal_num_tutor_assigned_pes: rand(10) + 1,
      pes_are_assigned: false,
      goal_num_tutor_assigned_spes: rand(4) + 1,
      spes_are_assigned: false
    )
  end

  let(:assignment_pe)                        do
    FactoryBot.create :assignment_pe, assignment: pe_assignment
  end
  let(:spe_assignment)                       do
    FactoryBot.create(
      :assignment,
      ecosystem: ecosystem,
      student: student,
      goal_num_tutor_assigned_pes: rand(10) + 1,
      pes_are_assigned: false,
      goal_num_tutor_assigned_spes: rand(4) + 1,
      spes_are_assigned: false
    )
  end
  let(:assignment_spe)                       do
    FactoryBot.create :assignment_spe, assignment: spe_assignment
  end
  let(:new_assignment)                       do
    FactoryBot.create(
      :assignment,
      ecosystem: ecosystem,
      student: student,
      goal_num_tutor_assigned_pes: rand(10) + 1,
      pes_are_assigned: false,
      goal_num_tutor_assigned_spes: rand(4) + 1,
      spes_are_assigned: false,
      book_containers_count: rand(10) + 1
    )
  end
  let!(:assigned_exercise_1)                 do
    FactoryBot.create(
      :assigned_exercise, assignment: new_assignment, exercise_uuid: student_pe.exercise_uuid
    )
  end
  let!(:assigned_exercise_2)                 do
    FactoryBot.create(
      :assigned_exercise, assignment: new_assignment, exercise_uuid: assignment_pe.exercise_uuid
    )
  end
  let!(:assigned_exercise_3)                 do
    FactoryBot.create(
      :assigned_exercise, assignment: new_assignment, exercise_uuid: assignment_spe.exercise_uuid
    )
  end

  let(:default_exercise_calculation)         do
    FactoryBot.create :exercise_calculation, :default, ecosystem: ecosystem
  end
  let!(:exercise_pools)                      do
    new_assignment.assigned_book_container_uuids.map do |book_container_uuid|
      FactoryBot.create(
        :exercise_pool,
        book_container_uuid: book_container_uuid,
        use_for_personalized_for_assignment_types: [ new_assignment.assignment_type ],
        exercises_count: rand(10) + 1
      )
    end
  end
  let!(:default_algorithm_exercise_calculation) do
    FactoryBot.create(
      :algorithm_exercise_calculation,
      exercise_calculation: default_exercise_calculation,
      exercise_uuids: exercise_pools.flat_map(&:exercise_uuids).shuffle
    )
  end

  context 'with no existing ExerciseCalculations' do
    before { exercise_calculation.destroy! }

    context 'with no default ExerciseCalculation' do
      before { default_exercise_calculation.destroy! }

      it 'does not upload default PEs and SPEs for the assignment' do
        expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_pes)
        expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_spes)

        subject
      end
    end

    context 'with a default ExerciseCalculation and some ExercisePools' do
      it 'uploads default PEs and SPEs for the assignment' do
        expect(OpenStax::Biglearn::Api).to receive(:update_assignment_pes) do |requests|
          requests.each do |request|
            expect(request[:exercise_uuids]).not_to be_empty
          end
        end
        expect(OpenStax::Biglearn::Api).to receive(:update_assignment_spes) do |requests|
          requests.each do |request|
            expect(request[:exercise_uuids]).not_to be_empty
          end
        end

        expect do
          subject
        end.to  not_change { default_exercise_calculation.reload.is_used_in_assignments }
           .and not_change { default_algorithm_exercise_calculation.reload.is_pending_for_student }
           .and not_change { default_algorithm_exercise_calculation.pending_assignment_uuids }
      end
    end
  end

  context 'with existing ExerciseCalculations' do
    before do
      exercise_calculation.update_attribute :is_used_in_assignments, false
      algorithm_exercise_calculation.update_attribute :is_pending_for_student, false
    end

    it 'does not upload default PEs and SPEs for the assignment, marks the ExerciseCalculation' +
       'as used and marks the AlgorithmExerciseCalculations for reupload' do
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_pes)
      expect(OpenStax::Biglearn::Api).not_to receive(:update_assignment_spes)

      expect do
        subject
      end.to  not_change { default_exercise_calculation.reload.is_used_in_assignments }
         .and not_change { default_algorithm_exercise_calculation.reload.is_pending_for_student }
         .and not_change { default_algorithm_exercise_calculation.pending_assignment_uuids }
         .and change { exercise_calculation.reload.is_used_in_assignments }.from(false).to(true)
         .and change { algorithm_exercise_calculation.reload.pending_assignment_uuids }.from([])
         .and change { algorithm_exercise_calculation.is_pending_for_student }.from(false).to(true)

      expect(Set.new algorithm_exercise_calculation.pending_assignment_uuids).to eq Set.new(
        [ pe_assignment, spe_assignment, new_assignment ].map(&:uuid)
      )
    end
  end
end

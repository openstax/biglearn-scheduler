require 'rails_helper'

RSpec.describe Assignment, type: :model do
  subject { FactoryBot.create :assignment }

  it { is_expected.to have_many(:assigned_exercises).dependent(:destroy) }
  it { is_expected.to have_many(:assignment_pes).dependent(:destroy) }
  it { is_expected.to have_many(:assignment_spes).dependent(:destroy) }

  it { is_expected.to belong_to(:ecosystem).optional }
  it { is_expected.to belong_to(:student).optional }

  it { is_expected.to validate_presence_of :course_uuid }
  it { is_expected.to validate_presence_of :ecosystem_uuid }
  it { is_expected.to validate_presence_of :student_uuid }

  it do
    is_expected.to(
      validate_numericality_of(:goal_num_tutor_assigned_spes).only_integer
                                                             .is_greater_than_or_equal_to(0)
                                                             .allow_nil
    )
  end
  it do
    is_expected.to(
      validate_numericality_of(:goal_num_tutor_assigned_pes).only_integer
                                                            .is_greater_than_or_equal_to(0)
                                                            .allow_nil
    )
  end

  context 'sequence numbers' do
    let(:student_uuid)    { SecureRandom.uuid }
    let(:assignment_type) { 'reading' }
    let(:current_time)    { Time.current }

    let!(:assignment_1) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time.yesterday,
                                     opens_at: current_time.yesterday - 2.days,
                                     student_history_at: current_time,
                                     is_deleted: false
    end
    let!(:assignment_2) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time.yesterday,
                                     opens_at: current_time.yesterday - 2.days,
                                     student_history_at: current_time,
                                     is_deleted: false
    end
    let!(:assignment_3) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time.yesterday,
                                     opens_at: current_time.yesterday - 1.day,
                                     student_history_at: current_time - 1.day,
                                     is_deleted: false
    end
    let!(:assignment_4) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time.yesterday,
                                     opens_at: current_time.yesterday - 1.day,
                                     student_history_at: current_time - 1.day,
                                     is_deleted: false
    end
    let!(:assignment_5) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time,
                                     opens_at: current_time.yesterday - 2.days,
                                     is_deleted: false
    end
    let!(:assignment_6) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time,
                                     opens_at: current_time.yesterday - 2.days,
                                     is_deleted: false
    end
    let!(:assignment_7) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time,
                                     opens_at: current_time.yesterday - 1.day,
                                     is_deleted: false
    end
    let!(:assignment_8) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time,
                                     opens_at: current_time.yesterday - 1.day,
                                     is_deleted: false
    end
    let!(:deleted_assignment) do
      FactoryBot.create :assignment, student_uuid: student_uuid,
                                     assignment_type: assignment_type,
                                     due_at: current_time,
                                     opens_at: current_time.yesterday - 2.days,
                                     is_deleted: true
    end

    context '#with_instructor_and_student_driven_sequence_numbers_subquery' do
      it 'assigns instructor sequence_numbers from is_deleted, due_at, opens_at and created_at' do
        assignments = Assignment.with_instructor_and_student_driven_sequence_numbers_subquery(
          student_uuids: [ student_uuid ], assignment_types: [ assignment_type ]
        ).to_a

        [
          assignment_1, assignment_2, assignment_3, assignment_4,
          assignment_5, assignment_6, assignment_7, assignment_8
        ].each_with_index do |assignment, index|
          assignment_with_sequence_numbers = assignments.find { |aa| aa.uuid == assignment.uuid }
          expect(assignment_with_sequence_numbers.instructor_driven_sequence_number).to eq index + 1
        end
      end

      it 'assigns student sequence_numbers from is_deleted, student_history_at and tiebreakers' do
        assignments = Assignment.with_instructor_and_student_driven_sequence_numbers_subquery(
          student_uuids: [ student_uuid ], assignment_types: [ assignment_type ]
        ).to_a

        [
          assignment_3, assignment_4, assignment_1, assignment_2
        ].each_with_index do |assignment, index|
          assignment_with_sequence_numbers = assignments.find { |aa| aa.uuid == assignment.uuid }
          expect(assignment_with_sequence_numbers.student_driven_sequence_number).to eq index + 1
        end

        [ assignment_5, assignment_6, assignment_7, assignment_8 ].each do |assignment|
          assignment_with_sequence_numbers = assignments.find { |aa| aa.uuid == assignment.uuid }
          expect(assignment_with_sequence_numbers.student_driven_sequence_number).to eq 5
        end
      end
    end

    context '#to_a_with_instructor_and_student_driven_sequence_numbers_cte' do
      it 'returns the given scope with sequence numbers' do
        assignments = Assignment.where(
          'instructor_driven_sequence_number < 4 AND student_driven_sequence_number < 4'
        ).to_a_with_instructor_and_student_driven_sequence_numbers_cte(
          student_uuids: [ student_uuid ], assignment_types: [ assignment_type ]
        )

        expect(assignments).to match_array [ assignment_1, assignment_3 ]
        assignment_1_with_sequence_numbers = assignments.find { |aa| aa.uuid == assignment_1.uuid }
        expect(assignment_1_with_sequence_numbers.instructor_driven_sequence_number).to eq 1
        expect(assignment_1_with_sequence_numbers.student_driven_sequence_number).to eq 3
        assignment_3_with_sequence_numbers = assignments.find { |aa| aa.uuid == assignment_3.uuid }
        expect(assignment_3_with_sequence_numbers.instructor_driven_sequence_number).to eq 3
        expect(assignment_3_with_sequence_numbers.student_driven_sequence_number).to eq 1
      end
    end
  end
end

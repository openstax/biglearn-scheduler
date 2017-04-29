require 'rails_helper'

RSpec.describe Services::UpdateExerciseCalculations::Service, type: :service do
  let(:service)                            { described_class.new }

  let(:given_algorithm_name)               { 'sparfa' }

  let(:given_calculation_uuid_1)           { SecureRandom.uuid }
  let(:num_exercise_uuids_1)               { rand(10) }
  let(:given_exercise_uuids_1)             { num_exercise_uuids_1.times.map { SecureRandom.uuid } }

  let(:given_calculation_uuid_2)           { SecureRandom.uuid }
  let(:num_exercise_uuids_2)               { rand(10) }
  let(:given_exercise_uuids_2)             { num_exercise_uuids_2.times.map { SecureRandom.uuid } }

  let(:given_calculation_uuid_3)           { SecureRandom.uuid }
  let(:num_exercise_uuids_3)               { rand(10) }
  let(:given_exercise_uuids_3)             { num_exercise_uuids_3.times.map { SecureRandom.uuid } }

  let(:exercise_uuids_by_calculation_uuid) do
    {
      given_calculation_uuid_1 => given_exercise_uuids_1,
      given_calculation_uuid_2 => given_exercise_uuids_2,
      given_calculation_uuid_3 => given_exercise_uuids_3
    }
  end

  let(:given_exercise_calculation_updates) do
    exercise_uuids_by_calculation_uuid.map do |calculation_uuid, exercise_uuids|
      {
        calculation_uuid: calculation_uuid,
        algorithm_name: given_algorithm_name,
        exercise_uuids: exercise_uuids
      }
    end
  end

  let(:action)                             do
    service.process(exercise_calculation_updates: given_exercise_calculation_updates)
  end
  let(:results)                            { action.fetch(:exercise_calculation_update_responses) }

  context 'when non-existing AssignmentSpeCalculation, AssignmentPeCalculation and' +
          ' StudentPeCalculation calculation_uuids are given' do
    it 'does not create new records and returns calculation_status: "calculation_unknown"' do
      expect { action }.to  not_change { AlgorithmAssignmentSpeCalculation.count }
                       .and not_change { AlgorithmAssignmentPeCalculation.count  }
                       .and not_change { AlgorithmStudentPeCalculation.count     }

      results.each { |result| expect(result[:calculation_status]).to eq 'calculation_unknown' }
    end
  end

  context 'when previously-existing AssignmentSpeCalculation, AssignmentPeCalculation and' +
          ' StudentPeCalculation calculation_uuids are given' do
    let!(:assignment_spe_calculation) do
      FactoryGirl.create :assignment_spe_calculation, uuid: given_calculation_uuid_1
    end

    let!(:assignment_pe_calculation) do
      FactoryGirl.create :assignment_pe_calculation, uuid: given_calculation_uuid_2
    end

    let!(:student_pe_calculation) do
      FactoryGirl.create :student_pe_calculation, uuid: given_calculation_uuid_3
    end

    context 'when non-existing AlgorithmAssignmentSpeCalculation,' +
            'AlgorithmAssignmentPeCalculation and AlgorithmStudentPeCalculation calculation_uuids' +
            ' and algorithm_name are given' do
      it 'creates new records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to  change { AlgorithmAssignmentSpeCalculation.count }.by(1)
                         .and change { AlgorithmAssignmentPeCalculation.count  }.by(1)
                         .and change { AlgorithmStudentPeCalculation.count     }.by(1)

        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_assignment_spe_calculation = AlgorithmAssignmentSpeCalculation.find_by(
          assignment_spe_calculation_uuid: given_calculation_uuid_1
        )
        expect(algorithm_assignment_spe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_assignment_spe_calculation.exercise_uuids).to eq given_exercise_uuids_1

        algorithm_assignment_pe_calculation = AlgorithmAssignmentPeCalculation.find_by(
          assignment_pe_calculation_uuid: given_calculation_uuid_2
        )
        expect(algorithm_assignment_pe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_assignment_pe_calculation.exercise_uuids).to eq given_exercise_uuids_2

        algorithm_student_pe_calculation = AlgorithmStudentPeCalculation.find_by(
          student_pe_calculation_uuid: given_calculation_uuid_3
        )
        expect(algorithm_student_pe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_student_pe_calculation.exercise_uuids).to eq given_exercise_uuids_3
      end
    end

    context 'when previously-existing AlgorithmAssignmentSpeCalculation,' +
            'AlgorithmAssignmentPeCalculation and AlgorithmStudentPeCalculation calculation_uuids' +
            ' and algorithm_name are given' do
      before do
        FactoryGirl.create :algorithm_assignment_spe_calculation,
                           assignment_spe_calculation: assignment_spe_calculation,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_assignment_pe_calculation,
                           assignment_pe_calculation: assignment_pe_calculation,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_student_pe_calculation,
                           student_pe_calculation: student_pe_calculation,
                           algorithm_name: given_algorithm_name
      end

      it 'updates the records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to  not_change { AlgorithmAssignmentSpeCalculation.count }
                         .and not_change { AlgorithmAssignmentPeCalculation.count  }
                         .and not_change { AlgorithmStudentPeCalculation.count     }

        calculation_uuids = results.map { |result| result[:calculation_uuid] }
        expect(calculation_uuids).to match_array exercise_uuids_by_calculation_uuid.keys
        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_assignment_spe_calculation = AlgorithmAssignmentSpeCalculation.find_by(
          assignment_spe_calculation_uuid: given_calculation_uuid_1
        )
        expect(algorithm_assignment_spe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_assignment_spe_calculation.exercise_uuids).to eq given_exercise_uuids_1

        algorithm_assignment_pe_calculation = AlgorithmAssignmentPeCalculation.find_by(
          assignment_pe_calculation_uuid: given_calculation_uuid_2
        )
        expect(algorithm_assignment_pe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_assignment_pe_calculation.exercise_uuids).to eq given_exercise_uuids_2

        algorithm_student_pe_calculation = AlgorithmStudentPeCalculation.find_by(
          student_pe_calculation_uuid: given_calculation_uuid_3
        )
        expect(algorithm_student_pe_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_student_pe_calculation.exercise_uuids).to eq given_exercise_uuids_3
      end
    end
  end
end

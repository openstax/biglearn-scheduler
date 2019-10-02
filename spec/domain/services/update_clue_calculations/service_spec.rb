require 'rails_helper'

RSpec.describe Services::UpdateClueCalculations::Service, type: :service do
  let(:service)                        { described_class.new }

  let(:given_algorithm_name)           { 'sparfa' }

  let(:given_calculation_uuid_1)       { SecureRandom.uuid }
  let(:given_clue_data_1)              do
    {
      minimum: 0.7,
      most_likely: 0.8,
      maximum: 0.9,
      is_real: true,
      ecosystem_uuid: SecureRandom.uuid
    }
  end

  let(:given_calculation_uuid_2)       { SecureRandom.uuid }
  let(:given_clue_data_2)              do
    {
      minimum: 0,
      most_likely: 0.5,
      maximum: 1,
      is_real: false
    }
  end

  let(:clue_data_by_calculation_uuid)  do
    {
      given_calculation_uuid_1 => given_clue_data_1,
      given_calculation_uuid_2 => given_clue_data_2
    }
  end

  let(:given_clue_calculation_updates) do
    clue_data_by_calculation_uuid.map do |calculation_uuid, clue_data|
      {
        calculation_uuid: calculation_uuid,
        algorithm_name: given_algorithm_name,
        clue_data: clue_data
      }
    end
  end

  let(:action)                         do
    service.process(clue_calculation_updates: given_clue_calculation_updates)
  end
  let(:results)                        { action.fetch(:clue_calculation_update_responses) }

  context 'when non-existing StudentClueCalculation and' +
          ' TeacherClueCalculation calculation_uuids are given' do
    it 'does not create new records and returns calculation_status: "calculation_unknown"' do
      expect { action }.to  not_change { AlgorithmStudentClueCalculation.count }
                       .and not_change { AlgorithmTeacherClueCalculation.count }

      results.each { |result| expect(result[:calculation_status]).to eq 'calculation_unknown' }
    end
  end

  context 'when previously-existing StudentClueCalculation and' +
          ' TeacherClueCalculation calculation_uuids are given' do
    let!(:student_clue_calculation) do
      FactoryBot.create :student_clue_calculation, uuid: given_calculation_uuid_1
    end

    let!(:teacher_clue_calculation) do
      FactoryBot.create :teacher_clue_calculation, uuid: given_calculation_uuid_2
    end

    context 'when non-existing AlgorithmStudentClueCalculation and' +
            ' AlgorithmTeacherClueCalculation calculation_uuids and algorithm_name are given' do
      it 'creates new records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to  change { AlgorithmStudentClueCalculation.count }.by(1)
                         .and change { AlgorithmTeacherClueCalculation.count }.by(1)

        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_student_clue_calculation = AlgorithmStudentClueCalculation.find_by(
          student_clue_calculation_uuid: given_calculation_uuid_1
        )
        expect(algorithm_student_clue_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_student_clue_calculation.clue_data).to eq given_clue_data_1.stringify_keys
        expect(algorithm_student_clue_calculation.clue_value).to(
          eq given_clue_data_1.fetch(:most_likely)
        )
        algorithm_teacher_clue_calculation = AlgorithmTeacherClueCalculation.find_by(
          teacher_clue_calculation_uuid: given_calculation_uuid_2
        )
        expect(algorithm_teacher_clue_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_teacher_clue_calculation.clue_data).to eq given_clue_data_2.stringify_keys
      end
    end

    context 'when previously-existing AlgorithmStudentClueCalculation and' +
            ' AlgorithmTeacherClueCalculation calculation_uuids and algorithm_name are given' do
      before do
        FactoryBot.create :algorithm_student_clue_calculation,
                           student_clue_calculation: student_clue_calculation,
                           algorithm_name: given_algorithm_name

        FactoryBot.create :algorithm_teacher_clue_calculation,
                           teacher_clue_calculation: teacher_clue_calculation,
                           algorithm_name: given_algorithm_name
      end

      it 'updates the records and returns calculation_status: "calculation_accepted"' do
      expect { action }.to  not_change { AlgorithmStudentClueCalculation.count }
                       .and not_change { AlgorithmTeacherClueCalculation.count }

        calculation_uuids = results.map { |result| result[:calculation_uuid] }
        expect(calculation_uuids).to match_array clue_data_by_calculation_uuid.keys
        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        algorithm_student_clue_calculation = AlgorithmStudentClueCalculation.find_by(
          student_clue_calculation_uuid: given_calculation_uuid_1
        )
        expect(algorithm_student_clue_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_student_clue_calculation.clue_data).to eq given_clue_data_1.stringify_keys
        # The student_uuid field cannot be updated after the record is created
        expect(algorithm_student_clue_calculation.clue_value).to(
          eq given_clue_data_1.fetch(:most_likely)
        )
        algorithm_teacher_clue_calculation = AlgorithmTeacherClueCalculation.find_by(
          teacher_clue_calculation_uuid: given_calculation_uuid_2
        )
        expect(algorithm_teacher_clue_calculation.algorithm_name).to eq given_algorithm_name
        expect(algorithm_teacher_clue_calculation.clue_data).to eq given_clue_data_2.stringify_keys
      end
    end
  end
end

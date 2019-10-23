require 'rails_helper'

RSpec.describe Services::FetchAlgorithmExerciseCalculations::Service, type: :service do
  let(:service)                  { described_class.new }

  let(:given_request_uuid_1)     { SecureRandom.uuid }
  let(:given_student_uuid_1)     { SecureRandom.uuid }
  let(:given_algorithm_name_1)   { [ 'local_query', 'biglearn_sparfa' ].sample }

  let(:given_request_uuid_2)     { SecureRandom.uuid }
  let(:given_calculation_uuid_1) { SecureRandom.uuid }

  let(:given_request_uuid_3)     { SecureRandom.uuid }
  let(:given_student_uuid_2)     { SecureRandom.uuid }
  let(:given_algorithm_name_2)   { [ 'local_query', 'biglearn_sparfa' ].sample }
  let(:given_calculation_uuid_2) { SecureRandom.uuid }

  let(:given_request_uuid_4)     { SecureRandom.uuid }
  let(:given_student_uuid_3)     { SecureRandom.uuid }
  let(:given_algorithm_name_3)   { [ 'local_query', 'biglearn_sparfa' ].sample }
  let(:given_calculation_uuid_3) { SecureRandom.uuid }

  let(:given_algorithm_exercise_calculation_requests) do
    [
      {
        request_uuid: given_request_uuid_1,
        student_uuid: given_student_uuid_1,
        algorithm_name: given_algorithm_name_1
      },
      { request_uuid: given_request_uuid_2, calculation_uuids: [ given_calculation_uuid_1 ] },
      {
        request_uuid: given_request_uuid_3,
        student_uuid: given_student_uuid_2,
        algorithm_name: given_algorithm_name_2,
        calculation_uuids: [ given_calculation_uuid_2 ]
      },
      {
        request_uuid: given_request_uuid_4,
        student_uuid: given_student_uuid_3,
        algorithm_name: given_algorithm_name_3,
        calculation_uuids: [ given_calculation_uuid_3 ]
      }
    ]
  end

  let(:action)  do
    service.process(
      algorithm_exercise_calculation_requests: given_algorithm_exercise_calculation_requests
    )
  end
  let(:results) { action.fetch(:algorithm_exercise_calculations) }

  context 'when non-existing AlgorithmExerciseCalculation calculation_uuids are given' do
    it 'returns no results' do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      expect(results).to be_empty
    end
  end

  context 'when previously-existing student_uuids and calculation_uuids are given' do
    let(:student_1)              { FactoryBot.create :student, uuid: given_student_uuid_1 }
    let(:exercise_calculation_1) { FactoryBot.create :exercise_calculation, student: student_1 }
    let!(:algorithm_exercise_calculation_1) do
      FactoryBot.create :algorithm_exercise_calculation,
                        exercise_calculation: exercise_calculation_1,
                        algorithm_name: given_algorithm_name_1
    end
    let!(:algorithm_exercise_calculation_2) do
      FactoryBot.create :algorithm_exercise_calculation, uuid: given_calculation_uuid_1
    end
    let(:student_2)              { FactoryBot.create :student, uuid: given_student_uuid_2 }
    let(:exercise_calculation_2) { FactoryBot.create :exercise_calculation, student: student_2 }
    let!(:algorithm_exercise_calculation_3) do
      FactoryBot.create :algorithm_exercise_calculation,
                        uuid: given_calculation_uuid_2,
                        exercise_calculation: exercise_calculation_2,
                        algorithm_name: given_algorithm_name_2
    end
    let(:student_3)              { FactoryBot.create :student, uuid: given_student_uuid_3 }
    let(:exercise_calculation_3) { FactoryBot.create :exercise_calculation, student: student_3 }
    let!(:algorithm_exercise_calculation_4) do
      FactoryBot.create :algorithm_exercise_calculation,
                        exercise_calculation: exercise_calculation_3,
                        algorithm_name: given_algorithm_name_3
    end
    let!(:algorithm_exercise_calculation_5) do
      FactoryBot.create :algorithm_exercise_calculation, uuid: given_calculation_uuid_3,
                                                         algorithm_name: given_algorithm_name_3
    end

    it 'returns the requested algorithm exercise calculations' do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      expect(results.size).to eq 3
      algorithm_exercise_calculation_by_uuid = [
        algorithm_exercise_calculation_1,
        algorithm_exercise_calculation_2,
        algorithm_exercise_calculation_3
      ].index_by(&:uuid)
      results.each do |result|
        expect(result.fetch(:request_uuid)).to be_in [
          given_request_uuid_1, given_request_uuid_2, given_request_uuid_3
        ]

        calculation = result.fetch(:calculations).first

        algorithm_exercise_calculation = algorithm_exercise_calculation_by_uuid.fetch(
          calculation.fetch(:calculation_uuid)
        )
        expect(calculation.fetch(:calculated_at)).to eq(
          algorithm_exercise_calculation.updated_at.iso8601
        )
        expect(calculation.fetch(:student_uuid)).to eq(
          algorithm_exercise_calculation.exercise_calculation.student_uuid
        )
        expect(calculation.fetch(:algorithm_name)).to(
          eq algorithm_exercise_calculation.algorithm_name
        )
        expect(calculation.fetch(:ecosystem_matrix_uuid)).to(
          eq algorithm_exercise_calculation.ecosystem_matrix_uuid
        )
        expect(calculation.fetch(:exercise_uuids)).to(
          eq algorithm_exercise_calculation.exercise_uuids
        )
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::FetchAlgorithmExerciseCalculations::Service, type: :service do
  let(:service)                  { described_class.new }

  let(:given_calculation_uuid_1) { SecureRandom.uuid }
  let(:given_calculation_uuid_2) { SecureRandom.uuid }

  let(:given_algorithm_exercise_calculation_requests) do
    [ given_calculation_uuid_1, given_calculation_uuid_2 ].map do |calculation_uuid|
      { calculation_uuid: calculation_uuid }
    end
  end

  let(:action)  do
    service.process(algorithm_exercise_calculations: given_algorithm_exercise_calculation_requests)
  end
  let(:results) { action.fetch(:algorithm_exercise_calculations) }

  context 'when non-existing AlgorithmExerciseCalculation calculation_uuids are given' do
    it 'returns no results' do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      expect(results).to be_empty
    end
  end

  context 'when previously-existing AlgorithmExerciseCalculation calculation_uuids are given' do
    let!(:algorithm_exercise_calculation_1) do
      FactoryBot.create :algorithm_exercise_calculation, uuid: given_calculation_uuid_2
    end
    let!(:algorithm_exercise_calculation_2) do
      FactoryBot.create :algorithm_exercise_calculation, uuid: given_calculation_uuid_1
    end

    it 'returns the requested algorithm exercise calculations' do
      expect { action }.not_to change { AlgorithmExerciseCalculation.count }

      expect(results.size).to eq 2
      algorithm_exercise_calculation_by_uuid = [
        algorithm_exercise_calculation_1, algorithm_exercise_calculation_2
      ].index_by(&:uuid)
      results.each do |result|
        algorithm_exercise_calculation = algorithm_exercise_calculation_by_uuid.fetch(
          result.fetch(:calculation_uuid)
        )

        expect(result.fetch(:algorithm_name)).to eq algorithm_exercise_calculation.algorithm_name
        expect(result.fetch(:ecosystem_matrix_uuid)).to(
          eq algorithm_exercise_calculation.ecosystem_matrix_uuid
        )
        expect(result.fetch(:exercise_uuids)).to eq algorithm_exercise_calculation.exercise_uuids
      end
    end
  end
end

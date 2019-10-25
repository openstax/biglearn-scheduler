require 'rails_helper'

RSpec.describe Services::EcosystemMatricesUpdated::Service, type: :service do
  let(:service)                          { described_class.new }

  let(:given_algorithm_name)             { 'biglearn_sparfa' }

  let(:given_calculation_uuid_1)         { SecureRandom.uuid }
  let(:given_calculation_uuid_2)         { SecureRandom.uuid }
  let(:given_calculation_uuids)          { [ given_calculation_uuid_1, given_calculation_uuid_2 ] }

  let(:given_ecosystem_matrices_updated) do
    given_calculation_uuids.map do |calculation_uuid|
      {
        calculation_uuid: calculation_uuid,
        algorithm_name: given_algorithm_name
      }
    end
  end

  let(:action)                           do
    service.process(ecosystem_matrices_updated: given_ecosystem_matrices_updated)
  end
  let(:results)                          { action.fetch(:ecosystem_matrix_updated_responses) }

  context "when non-existing EcosystemMatrixUpdate calculation_uuids are given" do
    it 'does not create new records and returns calculation_status: "calculation_unknown"' do
      expect { action }.to  not_change { AlgorithmEcosystemMatrixUpdate.count }

      results.each { |result| expect(result[:calculation_status]).to eq 'calculation_unknown' }
    end
  end

  context "when previously-existing EcosystemMatrixUpdate calculation_uuids are given" do
    let!(:ecosystem_matrix_update_1) do
      FactoryBot.create :ecosystem_matrix_update, uuid: given_calculation_uuid_1
    end

    let!(:ecosystem_matrix_update_2) do
      FactoryBot.create :ecosystem_matrix_update, uuid: given_calculation_uuid_2
    end

    context "when non-existing AlgorithmEcosystemMatrixUpdate" +
            " calculation_uuid and algorithm_name are given" do
      it 'creates new records and returns calculation_status: "calculation_accepted"' do
        expect { action }.to change { AlgorithmEcosystemMatrixUpdate.count }.by(2)

        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }

        new_algorithm_exercise_calculations = AlgorithmEcosystemMatrixUpdate.where(
          ecosystem_matrix_update_uuid: given_calculation_uuids
        )
        new_algorithm_exercise_calculations.each do |new_algorithm_exercise_calculation|
          expect(new_algorithm_exercise_calculation.algorithm_name).to eq given_algorithm_name
        end
      end
    end

    context "when previously-existing AlgorithmEcosystemMatrixUpdate" +
            " calculation_uuid and algorithm_name are given" do
      before do
        FactoryBot.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update_uuid: given_calculation_uuid_1,
                           algorithm_name: given_algorithm_name

        FactoryBot.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update_uuid: given_calculation_uuid_2,
                           algorithm_name: given_algorithm_name
      end

      it 'does not create new records and returns calculation_status: "calculation_accepted"' do
        expect { action }.not_to change { AlgorithmEcosystemMatrixUpdate.count }

        calculation_uuids = results.map { |result| result[:calculation_uuid] }
        expect(calculation_uuids).to match_array given_calculation_uuids
        results.each { |result| expect(result[:calculation_status]).to eq 'calculation_accepted' }
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Services::EcosystemMatricesUpdated::Service, type: :service do
  let(:service)                          { described_class.new }

  let(:given_algorithm_name)             { 'sparfa' }

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

  context "when non-existing AlgorithmEcosystemMatrixUpdate" +
          " calculation_uuid and algorithm_name are given" do
    it "creates new AlgorithmEcosystemMatrixUpdate records for the given updates" do
      expect { action }.to change { AlgorithmEcosystemMatrixUpdate.count }.by(2)

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
      FactoryGirl.create :algorithm_ecosystem_matrix_update,
                         ecosystem_matrix_update_uuid: given_calculation_uuid_1,
                         algorithm_name: given_algorithm_name

      FactoryGirl.create :algorithm_ecosystem_matrix_update,
                         ecosystem_matrix_update_uuid: given_calculation_uuid_2,
                         algorithm_name: given_algorithm_name
    end

    it "does not create new AlgorithmEcosystemMatrixUpdate records for the given updates" do
      expect { action }.not_to change { AlgorithmEcosystemMatrixUpdate.count }
    end
  end
end

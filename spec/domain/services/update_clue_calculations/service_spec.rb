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
    }.stringify_keys
  end

  let(:given_calculation_uuid_2)       { SecureRandom.uuid }
  let(:given_clue_data_2)              do
    {
      minimum: 0,
      most_likely: 0.5,
      maximum: 1,
      is_real: false
    }.stringify_keys
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

  context "when non-existing AlgorithmClueCalculation" +
          " calculation_uuid and algorithm_name are given" do
    it "creates new AlgorithmClueCalculation records for the given updates" do
      expect { action }.to change { AlgorithmClueCalculation.count }.by(2)

      new_algorithm_clue_calculations =
        AlgorithmClueCalculation.where(clue_calculation_uuid: clue_data_by_calculation_uuid.keys)
      new_algorithm_clue_calculations.each do |new_algorithm_clue_calculation|
        expect(new_algorithm_clue_calculation.algorithm_name).to eq given_algorithm_name

        calculation_uuid = new_algorithm_clue_calculation.clue_calculation_uuid
        clue_data = clue_data_by_calculation_uuid.fetch(calculation_uuid)
        expect(new_algorithm_clue_calculation.clue_data).to eq clue_data
      end
    end
  end

  context "when previously-existing AlgorithmClueCalculation" +
          " calculation_uuid and algorithm_name are given" do
    before do
      FactoryGirl.create :algorithm_clue_calculation,
                         clue_calculation_uuid: given_calculation_uuid_1,
                         algorithm_name: given_algorithm_name

      FactoryGirl.create :algorithm_clue_calculation,
                         clue_calculation_uuid: given_calculation_uuid_2,
                         algorithm_name: given_algorithm_name
    end

    it "updates the AlgorithmClueCalculation records with the given updates" do
      expect { action }.not_to change { AlgorithmClueCalculation.count }

      new_algorithm_clue_calculations =
        AlgorithmClueCalculation.where(clue_calculation_uuid: clue_data_by_calculation_uuid.keys)
      new_algorithm_clue_calculations.each do |new_algorithm_clue_calculation|
        expect(new_algorithm_clue_calculation.algorithm_name).to eq given_algorithm_name

        calculation_uuid = new_algorithm_clue_calculation.clue_calculation_uuid
        clue_data = clue_data_by_calculation_uuid.fetch(calculation_uuid)
        expect(new_algorithm_clue_calculation.clue_data).to eq clue_data
      end
    end
  end
end

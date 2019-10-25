require 'rails_helper'

RSpec.describe Services::FetchEcosystemMatrixUpdates::Service, type: :service do
  let(:service)              { described_class.new }

  let(:given_algorithm_name) { 'biglearn_sparfa' }

  let(:action)               { service.process(algorithm_name: given_algorithm_name) }

  context "when non-existing EcosystemMatrixUpdate algorithm_names are given" do
    it "an empty array of ecosystem_matrix_updates is returned" do
      expect(action.fetch(:ecosystem_matrix_updates)).to be_empty
    end
  end

  context "when previously-existing EcosystemMatrixUpdate algorithm_names are given" do
    let(:calculation_uuid_1)   { SecureRandom.uuid }
    let(:calculation_uuid_2)   { SecureRandom.uuid }

    let!(:ecosystem_matrix_update_1) do
      FactoryBot.create :ecosystem_matrix_update, uuid: calculation_uuid_1
    end
    let!(:ecosystem_matrix_update_2) do
      FactoryBot.create :ecosystem_matrix_update, uuid: calculation_uuid_2
    end

    context "when the EcosystemMatrixUpdates have already been updated" do
      before do
        FactoryBot.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update: ecosystem_matrix_update_1,
                           algorithm_name: given_algorithm_name
        ecosystem_matrix_update_1.algorithm_names << given_algorithm_name
        ecosystem_matrix_update_1.save!

        FactoryBot.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update: ecosystem_matrix_update_2,
                           algorithm_name: given_algorithm_name
        ecosystem_matrix_update_2.algorithm_names << given_algorithm_name
        ecosystem_matrix_update_2.save!
      end

      it "an empty array of ecosystem_matrix_updates is returned" do
        expect(action.fetch(:ecosystem_matrix_updates)).to be_empty
      end
    end

    context "when the EcosystemMatrixUpdates have not yet been updated" do
      it "the ecosystem_matrix_updates are returned" do
        ecosystem_matrix_updates_by_uuid = EcosystemMatrixUpdate.all.index_by(&:uuid)

        action.fetch(:ecosystem_matrix_updates).each do |response|
          ecosystem_matrix_update = ecosystem_matrix_updates_by_uuid.fetch(
            response.fetch(:calculation_uuid)
          )

          expect(response.fetch(:ecosystem_uuid)).to eq ecosystem_matrix_update.ecosystem_uuid
        end
      end
    end
  end
end

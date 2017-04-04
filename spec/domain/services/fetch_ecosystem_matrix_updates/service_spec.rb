require 'rails_helper'

RSpec.describe Services::FetchEcosystemMatrixUpdates::Service, type: :service do
  let(:service)              { described_class.new }

  let(:given_algorithm_name) { 'sparfa' }

  let(:action)               { service.process(algorithm_name: given_algorithm_name) }

  context "when non-existing EcosystemMatrixUpdate algorithm_names are given" do
    it "an empty array of ecosystem_matrix_updates is returned" do
      expect(action.fetch(:ecosystem_matrix_updates)).to be_empty
    end
  end

  context "when previously-existing EcosystemMatrixUpdate algorithm_names are given" do
    let(:calculation_uuid_1)   { SecureRandom.uuid }
    let(:calculation_uuid_2)   { SecureRandom.uuid }

    let(:ecosystem_uuid_1)     { SecureRandom.uuid }
    let(:ecosystem_uuid_2)     { SecureRandom.uuid }

    before do
      FactoryGirl.create :ecosystem_matrix_update, uuid: calculation_uuid_1,
                                                   ecosystem_uuid: ecosystem_uuid_1

      FactoryGirl.create :ecosystem_matrix_update, uuid: calculation_uuid_2,
                                                   ecosystem_uuid: ecosystem_uuid_2
    end

    context "when the EcosystemMatrixUpdates have already been updated" do
      before do
        FactoryGirl.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update_uuid: calculation_uuid_1,
                           algorithm_name: given_algorithm_name

        FactoryGirl.create :algorithm_ecosystem_matrix_update,
                           ecosystem_matrix_update_uuid: calculation_uuid_2,
                           algorithm_name: given_algorithm_name
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

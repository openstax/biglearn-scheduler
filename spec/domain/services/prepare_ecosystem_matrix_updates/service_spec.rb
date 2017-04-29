require 'rails_helper'

RSpec.describe Services::PrepareEcosystemMatrixUpdates::Service, type: :service do
  subject { described_class.new }

  context 'with no Ecosystems or Responses' do
    it 'does not request any ecosystem matrix updates' do
      expect { subject.process }.to  not_change { Response.count                       }
                                .and not_change { EcosystemMatrixUpdate.count          }
                                .and not_change { AlgorithmEcosystemMatrixUpdate.count }
    end
  end

  context 'with existing Ecosystems and Responses' do
    before(:all) do
      DatabaseCleaner.start

      @ecosystem_1 = FactoryGirl.create :ecosystem
      @ecosystem_2 = FactoryGirl.create :ecosystem

      @response_1 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_1.uuid,
                                       used_in_ecosystem_matrix_updates: false
      @response_2 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_1.uuid,
                                       used_in_ecosystem_matrix_updates: false

      @response_3 = FactoryGirl.create :response,
                                       ecosystem_uuid: @ecosystem_2.uuid,
                                       used_in_ecosystem_matrix_updates: true

      @unprocessed_responses = [ @response_1, @response_2 ]
    end

    after(:all)  { DatabaseCleaner.clean }

    it 'creates the EcosystemMatrixUpdate records and marks the Response objects as processed' do
      expect { subject.process }.to  not_change { Response.count                       }
                                .and change     { EcosystemMatrixUpdate.count          }.by(1)
                                .and not_change { AlgorithmEcosystemMatrixUpdate.count }

      @unprocessed_responses.each do |response|
        expect(response.reload.used_in_ecosystem_matrix_updates).to eq true
      end
    end

    context 'with existing EcosystemMatrixUpdates and AlgorithmEcosystemMatrixUpdates' do
      before(:all) do
        DatabaseCleaner.start

        @ecosystem_matrix_update_1 = FactoryGirl.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_1.uuid
        @ecosystem_matrix_update_2 = FactoryGirl.create :ecosystem_matrix_update,
                                                        ecosystem_uuid: @ecosystem_2.uuid

        @algorithm_ecosystem_matrix_update_1 =
          FactoryGirl.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_1
        @algorithm_ecosystem_matrix_update_2 =
          FactoryGirl.create :algorithm_ecosystem_matrix_update,
                             ecosystem_matrix_update: @ecosystem_matrix_update_2
      end

      after(:all)  { DatabaseCleaner.clean }

      it 'marks the Response objects as processed and' +
         ' deletes AlgorithmEcosystemMatrixUpdates that need to be updated' do
        expect { subject.process }.to  not_change { Response.count                       }
                                  .and not_change { EcosystemMatrixUpdate.count          }
                                  .and change     { AlgorithmEcosystemMatrixUpdate.count }.by(-1)

        @unprocessed_responses.each do |response|
          expect(response.reload.used_in_ecosystem_matrix_updates).to eq true
        end
      end
    end
  end
end

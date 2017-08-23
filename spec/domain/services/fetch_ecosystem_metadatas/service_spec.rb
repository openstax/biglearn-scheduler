require 'rails_helper'

RSpec.describe Services::FetchEcosystemMetadatas::Service, type: :service do
  subject { described_class.new }

  context 'with no ecosystem metadatas' do
    it 'does not create any ecosystems' do
      expect { subject.process }.not_to change { Ecosystem.count }
    end
  end

  context 'with some existing ecosystems and ecosystem metadatas' do
    let!(:ecosystem_1)                 { FactoryGirl.create :ecosystem }
    let!(:ecosystem_2)                 { FactoryGirl.create :ecosystem }

    let(:existing_ecosystem_metadatas) do
      [ ecosystem_1, ecosystem_2 ].each_with_index.map do |ecosystem, index|
        { uuid: ecosystem.uuid, metadata_sequence_number: index }
      end
    end
    let(:num_existing_ecosystems)      { existing_ecosystem_metadatas.size }
    let(:num_new_ecosystems)           { 2 }
    let(:new_ecosystem_metadatas)      do
      num_new_ecosystems.times.map do |new_index|
        { uuid: SecureRandom.uuid, metadata_sequence_number: new_index + num_existing_ecosystems }
      end
    end
    let(:ecosystem_metadatas)          { existing_ecosystem_metadatas + new_ecosystem_metadatas }
    let(:ecosystem_metadatas_response) { { ecosystem_responses: ecosystem_metadatas } }

    it 'creates all new ecosystems' do
      expect(OpenStax::Biglearn::Api).to(
        receive(:fetch_ecosystem_metadatas).and_return(ecosystem_metadatas_response)
      )

      expect { subject.process }.to  change     { Ecosystem.count         }.by(num_new_ecosystems)
                                .and not_change { ecosystem_1.reload.uuid }
                                .and not_change { ecosystem_2.reload.uuid }

      new_ecosystem_uuids = new_ecosystem_metadatas.map { |metadata| metadata.fetch :uuid }
      new_ecosystems = Ecosystem.where uuid: new_ecosystem_uuids
      new_ecosystems.each do |ecosystem|
        expect(ecosystem.sequence_number).to eq 0
        expect(ecosystem.exercise_uuids).to eq []
      end
    end
  end
end

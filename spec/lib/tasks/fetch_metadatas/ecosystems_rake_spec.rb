require 'rake_helper'

RSpec.describe 'fetch_metadatas:ecosystems', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  context 'with no ecosystem metadatas' do
    it 'does not create any ecosystems' do
      expect { subject.invoke }.not_to change { Ecosystem.count }
    end
  end

  context 'with some exiting ecosystems and ecosystem metadatas' do
    let!(:ecosystem_1)                 { FactoryGirl.create :ecosystem }
    let!(:ecosystem_2)                 { FactoryGirl.create :ecosystem }

    let(:existing_ecosystem_metadatas) do
      [ ecosystem_1, ecosystem_2 ].map { |ecosystem| { uuid: ecosystem.uuid } }
    end
    let(:num_new_ecosystems)           { 2 }
    let(:new_ecosystem_metadatas)      do
      num_new_ecosystems.times.map { { uuid: SecureRandom.uuid } }
    end
    let(:ecosystem_metadatas)          { existing_ecosystem_metadatas + new_ecosystem_metadatas }
    let(:ecosystem_metadatas_response) { { ecosystem_responses: ecosystem_metadatas } }

    it 'creates all new ecosystems' do
      allow(OpenStax::Biglearn::Api).to(
        receive(:fetch_ecosystem_metadatas).and_return(ecosystem_metadatas_response)
      )

      expect { subject.invoke }.to  change     { Ecosystem.count         }.by(num_new_ecosystems)
                               .and not_change { ecosystem_1.reload.uuid }
                               .and not_change { ecosystem_2.reload.uuid }

      new_ecosystem_uuids = new_ecosystem_metadatas.map { |metadata| metadata.fetch :uuid }
      new_ecosystems = Ecosystem.where uuid: new_ecosystem_uuids
      new_ecosystems.each { |ecosystem| expect(ecosystem.sequence_number).to eq 0 }
    end
  end
end

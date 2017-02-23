require 'rake_helper'

ASSIGNMENT_TYPES = [ 'reading', 'homework', 'practice', 'concept-coach' ]

RSpec.describe 'fetch_events:ecosystems', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'calls the appropriate service' do
    service_class = Services::FetchEcosystemEvents::Service
    service_spy = instance_spy(service_class)
    expect(service_class).to receive(:new).and_return(service_spy)
    expect(service_spy).to receive(:process)

    subject.invoke
  end
end

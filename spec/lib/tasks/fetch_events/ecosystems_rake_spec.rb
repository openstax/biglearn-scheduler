require 'rake_helper'

RSpec.describe 'fetch_events:ecosystems', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end
end

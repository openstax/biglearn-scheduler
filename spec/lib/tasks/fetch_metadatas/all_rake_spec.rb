require 'rake_helper'

RSpec.describe 'fetch_metadatas:all', type: :task do
  include_context 'rake'

  it 'includes fetch_events:ecosystems and fetch_events:courses as prerequisites' do
    expect(subject.prerequisites).to eq ['ecosystems', 'courses']
  end
end

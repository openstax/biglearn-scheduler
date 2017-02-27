require 'rake_helper'

RSpec.describe 'update_exercises:all', type: :task do
  include_context 'rake'

  it 'includes update_exercises:assignments and update_exercises:practice_worst_areas as prereqs' do
    expect(subject.prerequisites).to eq ['assignments', 'practice_worst_areas']
  end
end

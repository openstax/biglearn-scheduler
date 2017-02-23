require 'rake_helper'

RSpec.describe 'update_clues:all', type: :task do
  include_context 'rake'

  it 'includes update_clues:students and update_clues:teachers as prerequisites' do
    expect(subject.prerequisites).to eq ['students', 'teachers']
  end
end

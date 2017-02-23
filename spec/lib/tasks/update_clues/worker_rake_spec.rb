require 'rake_helper'

RSpec.describe 'update_clues:worker', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'instantiates and starts a Worker for the update_clues:all task' do
    worker_spy = instance_spy(Worker)
    expect(Worker).to receive(:new).with(:'update_clues:all').and_return(worker_spy)
    expect(worker_spy).to receive(:start)

    subject.invoke
  end
end

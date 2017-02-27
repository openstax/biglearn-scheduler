require 'rake_helper'

RSpec.describe 'update_exercises:worker', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'instantiates and starts a Worker for the update_exercises:all task' do
    worker_spy = instance_spy(Worker)
    expect(Worker).to receive(:new).with(:'update_exercises:all').and_return(worker_spy)
    expect(worker_spy).to receive(:start)

    subject.invoke
  end
end

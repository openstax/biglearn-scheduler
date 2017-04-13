require 'rake_helper'

RSpec.describe 'fetch_events:all', type: :task do
  include_context 'rake'

  it 'calls fetch_events:ecosystems and fetch_events:courses' do
    task_1 = Rake::Task.define_task :'fetch_events:ecosystems'
    expect(task_1).to receive(:reenable)
    expect(task_1).to receive(:invoke)

    task_2 = Rake::Task.define_task :'fetch_events:courses'
    expect(task_2).to receive(:reenable)
    expect(task_2).to receive(:invoke)

    subject.invoke
  end
end

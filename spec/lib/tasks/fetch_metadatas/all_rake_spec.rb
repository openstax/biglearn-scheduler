require 'rake_helper'

RSpec.describe 'fetch_metadatas:all', type: :task do
  include_context 'rake'

  it 'calls fetch_metadatas:ecosystems and fetch_metadatas:courses' do
    task_1 = Rake::Task.define_task :'fetch_metadatas:ecosystems'
    expect(task_1).to receive(:reenable)
    expect(task_1).to receive(:invoke)

    task_2 = Rake::Task.define_task :'fetch_metadatas:courses'
    expect(task_2).to receive(:reenable)
    expect(task_2).to receive(:invoke)

    subject.invoke
  end
end

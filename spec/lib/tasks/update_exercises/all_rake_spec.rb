require 'rake_helper'

RSpec.describe 'update_exercises:all', type: :task do
  include_context 'rake'

  it 'calls update_exercises:assignments and update_exercises:practice_worst_areas' do
    task_1 = Rake::Task.define_task :'update_exercises:assignments'
    expect(task_1).to receive(:reenable)
    expect(task_1).to receive(:invoke)

    task_2 = Rake::Task.define_task :'update_exercises:practice_worst_areas'
    expect(task_2).to receive(:reenable)
    expect(task_2).to receive(:invoke)

    subject.invoke
  end
end

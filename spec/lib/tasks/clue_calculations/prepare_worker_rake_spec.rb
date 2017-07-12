require 'rake_helper'

RSpec.describe 'clue_calculations:prepare:worker', type: :task do
  include_context 'rake'

  let(:command)   { Tasks::ApplicationHelper::DAEMON_COMMANDS.sample.to_s }

  let(:task_name) { @task_name.sub(':worker', '') }

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'sends the given command to the daemon' do
    worker_spy = instance_spy(Worker)
    expect(Worker).to receive(:new).with(task_name).and_return(worker_spy)
    expect(worker_spy).to receive(:run)
    expect(Daemons).to receive(:run_proc) do |sanitized_task_name, options, &block|
      expect(sanitized_task_name).to eq task_name.gsub(':', '_')
      expect(options[:ARGV].first).to eq command
      block.call
    end

    subject.invoke command
  end
end

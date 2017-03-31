require 'rails_helper'

RSpec.describe Worker, type: :lib do
  subject { described_class.new :'test:task' }

  before  { TestTaskCounter.reset }

  context '#run_once' do
    it 'runs the given task once' do
      expect{ subject.run_once }.not_to raise_error
      expect(TestTaskCounter.count).to eq 1
    end
  end

  context '#run' do
    context 'when the worker is ahead of schedule' do
      let(:run_every) { 10.seconds }

      it 'runs the given task continuously with sleep until halt or error' do
        # Stub out the sleep method so the test completes faster
        sleep_calls = 0
        allow(subject).to receive(:sleep) do |interval|
          sleep_calls = sleep_calls + 1

          # Since sleep is stubbed, we expect the Worker to attempt to sleep
          # run_every seconds after the first call, 2*run_every seconds after the second call, etc
          # to compensate for being ahead of schedule
          expect(interval).to be_within(0.1).of(run_every * sleep_calls)
        end

        # Catch the error raised by the test task so the Worker aborts but the test still passes
        expect { subject.run run_every }.to raise_error(TestTaskComplete)
        expect(TestTaskCounter.count).to eq TestTaskCounter::MAX_COUNT
      end
    end

    context 'when the worker is behind schedule' do
      let(:run_every) { 0.seconds }

      it 'runs the given task continuously without sleep until halt or error' do
        expect(subject).not_to receive(:sleep)

        # Catch the error raised by the test task so the Worker aborts but the test still passes
        expect { subject.run run_every }.to raise_error(TestTaskComplete)
        expect(TestTaskCounter.count).to eq TestTaskCounter::MAX_COUNT
      end
    end
  end
end

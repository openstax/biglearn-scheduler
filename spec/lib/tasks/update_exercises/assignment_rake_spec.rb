require 'rake_helper'

RSpec.describe 'update_exercises:assignments', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'calls the appropriate service' do
    service_class_1 = Services::PrepareAssignmentExerciseCalculations::Service
    service_spy_1 = instance_spy(service_class_1)
    expect(service_class_1).to receive(:new).and_return(service_spy_1)
    expect(service_spy_1).to receive(:process)

    service_class_2 = Services::UploadAssignmentPeCalculations::Service
    service_spy_2 = instance_spy(service_class_2)
    expect(service_class_2).to receive(:new).and_return(service_spy_2)
    expect(service_spy_2).to receive(:process)

    service_class_3 = Services::UploadAssignmentSpeCalculations::Service
    service_spy_3 = instance_spy(service_class_3)
    expect(service_class_3).to receive(:new).and_return(service_spy_3)
    expect(service_spy_3).to receive(:process)

    subject.invoke
  end
end

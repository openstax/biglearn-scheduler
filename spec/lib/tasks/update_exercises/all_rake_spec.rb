require 'rake_helper'

RSpec.describe 'update_exercises:all', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'calls the appropriate services' do
    service_class_1 = Services::PrepareExerciseCalculations::Service
    service_spy_1 = instance_spy(service_class_1)
    expect(service_class_1).to receive(:new).and_return(service_spy_1)
    expect(service_spy_1).to receive(:process)

    service_class_2 = Services::UpdateStudentHistory::Service
    service_spy_2 = instance_spy(service_class_2)
    expect(service_class_2).to receive(:new).and_return(service_spy_2)
    expect(service_spy_2).to receive(:process)

    service_class_3 = Services::UploadAssignmentExercises::Service
    service_spy_3 = instance_spy(service_class_3)
    expect(service_class_3).to receive(:new).and_return(service_spy_3)
    expect(service_spy_3).to receive(:process)

    service_class_4 = Services::UploadStudentExercises::Service
    service_spy_4 = instance_spy(service_class_4)
    expect(service_class_4).to receive(:new).and_return(service_spy_4)
    expect(service_spy_4).to receive(:process)

    subject.invoke
  end
end

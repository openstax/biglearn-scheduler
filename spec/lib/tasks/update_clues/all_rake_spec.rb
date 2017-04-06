require 'rake_helper'

RSpec.describe 'update_clues:all', type: :task do
  include_context 'rake'

  it 'includes the environment as prerequisite' do
    expect(subject.prerequisites).to eq ['environment']
  end

  it 'calls the appropriate services' do
    service_class_1 = Services::PrepareClueCalculations::Service
    service_spy_1 = instance_spy(service_class_1)
    expect(service_class_1).to receive(:new).and_return(service_spy_1)
    expect(service_spy_1).to receive(:process)

    service_class_2 = Services::UploadStudentClueCalculations::Service
    service_spy_2 = instance_spy(service_class_2)
    expect(service_class_2).to receive(:new).and_return(service_spy_2)
    expect(service_spy_2).to receive(:process)

    service_class_3 = Services::UploadTeacherClueCalculations::Service
    service_spy_3 = instance_spy(service_class_3)
    expect(service_class_3).to receive(:new).and_return(service_spy_3)
    expect(service_spy_3).to receive(:process)

    subject.invoke
  end
end

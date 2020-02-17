require 'rails_helper'

RSpec.describe UpdateRosterSideEffectsJob, type: :job do
  subject { described_class.perform_later course_uuids: course_uuids }

  let(:teacher_clue_calculation) { FactoryBot.create :teacher_clue_calculation }
  let(:course_uuids)             { [ teacher_clue_calculation.course_container.course_uuid ] }

  it 'marks the teacher_clue_calculation for recalculation' do
    expect { subject }.to change { teacher_clue_calculation.reload.recalculate_at }.from(nil)
  end
end

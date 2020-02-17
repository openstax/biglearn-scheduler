require 'rails_helper'

RSpec.describe UpdateCourseEcosystemSideEffectsJob, type: :job do
  subject { described_class.perform_later course_uuids: course_uuids }

  let(:student_clue_calculation) { FactoryBot.create :student_clue_calculation }
  let(:course_uuids)             { [ student_clue_calculation.student.course_uuid ] }

  it 'marks the teacher_clue_calculation for recalculation' do
    expect { subject }.to change { student_clue_calculation.reload.recalculate_at }.from(nil)
  end
end

require 'rails_helper'

RSpec.describe AssignmentSpe, type: :model do
  subject { FactoryGirl.create :assignment_spe }

  it { is_expected.to validate_presence_of :student_uuid }
  it { is_expected.to validate_presence_of :assignment_uuid }
  it { is_expected.to validate_presence_of :history_type }
  it { is_expected.to validate_presence_of :exercise_uuid }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to([:assignment_uuid, :history_type])
                                            .case_insensitive
    )
  end
end

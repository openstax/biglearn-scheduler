require 'rails_helper'

RSpec.describe AssignmentPe, type: :model do
  subject { FactoryGirl.create :assignment_pe }

  it { is_expected.to belong_to :algorithm_exercise_calculation }
  it { is_expected.to belong_to :assignment }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid)
        .scoped_to(:assignment_uuid, :algorithm_exercise_calculation_uuid)
        .case_insensitive
    )
  end
end

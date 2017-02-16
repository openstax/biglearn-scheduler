require 'rails_helper'

RSpec.describe Assignment, type: :model do
  subject { FactoryGirl.create :assignment }

  it { is_expected.to validate_presence_of :course_uuid }
  it { is_expected.to validate_presence_of :student_uuid }
  it { is_expected.to validate_presence_of :goal_num_spes }
  it { is_expected.to validate_presence_of :goal_num_pes }

  it do
    is_expected.to(
      validate_numericality_of(:goal_num_spes).only_integer.is_greater_than_or_equal_to(0)
    )
  end
  it do
    is_expected.to(
      validate_numericality_of(:goal_num_pes).only_integer.is_greater_than_or_equal_to(0)
    )
  end
end

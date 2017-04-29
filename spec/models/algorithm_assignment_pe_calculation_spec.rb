require 'rails_helper'

RSpec.describe AlgorithmAssignmentPeCalculation, type: :model do
  subject { FactoryGirl.create :algorithm_assignment_pe_calculation }

  it { is_expected.to belong_to :assignment_pe_calculation }

  it { is_expected.to validate_presence_of(:assignment_pe_calculation) }
  it { is_expected.to validate_presence_of(:algorithm_name) }

  it do
    is_expected.to(
      validate_uniqueness_of(:algorithm_name).scoped_to(:assignment_pe_calculation_uuid)
                                             .case_insensitive
    )
  end
end

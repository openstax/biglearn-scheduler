require 'rails_helper'

RSpec.describe AlgorithmAssignmentSpeCalculation, type: :model do
  subject { FactoryGirl.create :algorithm_assignment_spe_calculation }

  it { is_expected.to validate_presence_of(:assignment_spe_calculation_uuid) }
  it { is_expected.to validate_presence_of(:algorithm_name) }

  it do
    is_expected.to(
      validate_uniqueness_of(:algorithm_name).scoped_to(:assignment_spe_calculation_uuid)
                                             .case_insensitive
    )
  end
end

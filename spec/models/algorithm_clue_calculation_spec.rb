require 'rails_helper'

RSpec.describe AlgorithmClueCalculation, type: :model do
  subject { FactoryGirl.create :algorithm_clue_calculation }

  it { is_expected.to validate_presence_of(:clue_calculation_uuid) }
  it { is_expected.to validate_presence_of(:algorithm_name) }

  it do
    is_expected.to(
      validate_uniqueness_of(:algorithm_name).scoped_to(:clue_calculation_uuid).case_insensitive
    )
  end
end

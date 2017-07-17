require 'rails_helper'

RSpec.describe Ecosystem, type: :model do
  subject { FactoryGirl.create :ecosystem }

  it { is_expected.to have_many(:ecosystem_exercises).dependent(:destroy) }

  it { is_expected.to validate_presence_of :sequence_number }

  it do
    is_expected.to(
      validate_numericality_of(:sequence_number).only_integer.is_greater_than_or_equal_to(0)
    )
  end
end

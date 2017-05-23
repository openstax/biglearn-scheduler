require 'rails_helper'

RSpec.describe Course, type: :model do
  subject { FactoryGirl.create :course }

  it { is_expected.to have_many(:students).dependent(:destroy) }

  it { is_expected.to validate_presence_of :sequence_number }
  it { is_expected.to validate_presence_of :ecosystem_uuid }

  it do
    is_expected.to(
      validate_numericality_of(:sequence_number).only_integer.is_greater_than_or_equal_to(0)
    )
  end
end

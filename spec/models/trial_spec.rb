require 'rails_helper'

RSpec.describe Trial, type: :model do
  subject { FactoryGirl.create :trial }

  it { is_expected.to validate_presence_of :ecosystem_uuid }
end

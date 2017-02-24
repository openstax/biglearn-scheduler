require 'rails_helper'

RSpec.describe Exercise, type: :model do
  subject { FactoryGirl.create :exercise }

  it { is_expected.to validate_presence_of :group_uuid }
  it { is_expected.to validate_presence_of :version }
end

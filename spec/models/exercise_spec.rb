require 'rails_helper'

RSpec.describe Exercise, type: :model do
  subject { FactoryGirl.create :exercise }

  it { is_expected.to validate_presence_of :group_uuid }
  it { is_expected.to validate_presence_of :version }
  it { is_expected.to validate_presence_of :exercise_pool_uuids }

  it { is_expected.to validate_uniqueness_of(:version).scoped_to(:group_uuid).case_insensitive }
end

require 'rails_helper'

RSpec.describe AssignmentSpe, type: :model do
  subject { FactoryGirl.create :assignment_spe }

  it { is_expected.to validate_presence_of :assignment_uuid }
  it { is_expected.to validate_presence_of :exercise_uuid }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to(:assignment_uuid).case_insensitive
    )
  end
end

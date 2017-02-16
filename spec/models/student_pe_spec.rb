require 'rails_helper'

RSpec.describe StudentPe, type: :model do
  subject { FactoryGirl.create :student_pe }

  it { is_expected.to validate_presence_of :student_uuid }
  it { is_expected.to validate_presence_of :exercise_uuid }

  it do
    is_expected.to validate_uniqueness_of(:exercise_uuid).scoped_to(:student_uuid).case_insensitive
  end
end

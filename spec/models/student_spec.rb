require 'rails_helper'

RSpec.describe Student, type: :model do
  subject { FactoryGirl.create :student }

  it { is_expected.to have_many(:assignments) }

  it { is_expected.to have_many(:responses) }

  it { is_expected.to have_many(:exercise_calculations).dependent(:destroy) }

  it { is_expected.to belong_to :course }

  it { is_expected.to validate_presence_of :course_container_uuids }
end

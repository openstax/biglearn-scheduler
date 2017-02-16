require 'rails_helper'

RSpec.describe ExercisePool, type: :model do
  subject { FactoryGirl.create :exercise_pool }

  it { is_expected.to validate_presence_of :ecosystem_uuid }
  it { is_expected.to validate_presence_of :book_container_uuid }
end

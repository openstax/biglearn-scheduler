require 'rails_helper'

RSpec.describe ExerciseGroup, type: :model do
  subject { FactoryGirl.create :exercise_group }

  it { is_expected.to have_many(:exercises).dependent(:destroy)              }

  it { is_expected.to validate_presence_of(:response_count)                  }

  it { is_expected.to validate_numericality_of(:response_count).only_integer }
end

require 'rails_helper'

RSpec.describe Exercise, type: :model do
  subject { FactoryBot.create :exercise }

  it { is_expected.to have_many(:ecosystem_exercises).dependent(:destroy) }
  it { is_expected.to have_many :responses }

  it { is_expected.to belong_to(:exercise_group)                          }

  it { is_expected.to validate_presence_of :group_uuid }
  it { is_expected.to validate_presence_of :version }
end

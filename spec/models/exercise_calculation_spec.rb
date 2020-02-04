require 'rails_helper'

RSpec.describe ExerciseCalculation, type: :model do
  subject { FactoryBot.create :exercise_calculation }

  it { is_expected.to have_many(:algorithm_exercise_calculations).dependent(:destroy) }

  it { is_expected.to belong_to :ecosystem }

  # Shoulda matchers is not smart enough to handle our association,
  # which has a conditional presence validation
  #it { is_expected.to belong_to(:student) }

  it { is_expected.to validate_presence_of(:student) }
end

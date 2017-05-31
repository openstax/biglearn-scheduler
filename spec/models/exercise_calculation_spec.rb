require 'rails_helper'

RSpec.describe ExerciseCalculation, type: :model do
  subject { FactoryGirl.create :exercise_calculation }

  it { is_expected.to have_many(:algorithm_exercise_calculations).dependent(:destroy) }

  it { is_expected.to belong_to :ecosystem }
  it { is_expected.to belong_to :student }

  it do
    is_expected.to(
      validate_uniqueness_of(:student_uuid).scoped_to(:ecosystem_uuid).case_insensitive
    )
  end
end

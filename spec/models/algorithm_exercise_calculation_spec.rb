require 'rails_helper'

RSpec.describe AlgorithmExerciseCalculation, type: :model do
  subject { FactoryGirl.create :algorithm_exercise_calculation }

  it { is_expected.to have_many(:assignment_spes).dependent(:destroy) }
  it { is_expected.to have_many(:assignment_pes).dependent(:destroy) }
  it { is_expected.to have_many(:student_pes).dependent(:destroy) }

  it { is_expected.to belong_to :exercise_calculation }

  it { is_expected.to validate_presence_of(:algorithm_name) }
  it { is_expected.to validate_presence_of(:exercise_uuids) }

  it do
    is_expected.to(
      validate_uniqueness_of(:algorithm_name).scoped_to(:exercise_calculation_uuid)
                                             .case_insensitive
    )
  end
end

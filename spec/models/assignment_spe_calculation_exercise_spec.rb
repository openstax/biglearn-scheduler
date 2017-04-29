require 'rails_helper'

RSpec.describe AssignmentSpeCalculationExercise, type: :model do
  subject { FactoryGirl.create :assignment_spe_calculation_exercise }

  it { is_expected.to belong_to :assignment_spe_calculation }

  it { is_expected.to validate_presence_of(:assignment_spe_calculation) }
  it { is_expected.to validate_presence_of(:exercise_uuid) }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to(:assignment_spe_calculation_uuid)
                                            .case_insensitive
    )
  end
end

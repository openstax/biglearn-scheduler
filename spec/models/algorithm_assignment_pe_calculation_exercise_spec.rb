require 'rails_helper'

RSpec.describe AlgorithmAssignmentPeCalculationExercise, type: :model do
  subject { FactoryGirl.create :algorithm_assignment_pe_calculation_exercise }

  it { is_expected.to validate_presence_of(:algorithm_assignment_pe_calculation_uuid) }
  it { is_expected.to validate_presence_of(:exercise_uuid) }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to(:algorithm_assignment_pe_calculation_uuid)
                                            .case_insensitive
    )
  end
end

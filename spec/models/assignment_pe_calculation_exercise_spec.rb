require 'rails_helper'

RSpec.describe AssignmentPeCalculationExercise, type: :model do
  subject { FactoryGirl.create :assignment_pe_calculation_exercise }

  it { is_expected.to validate_presence_of(:assignment_pe_calculation_uuid) }
  it { is_expected.to validate_presence_of(:exercise_uuid) }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to(:assignment_pe_calculation_uuid)
                                            .case_insensitive
    )
  end
end

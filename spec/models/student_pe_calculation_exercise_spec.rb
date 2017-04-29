require 'rails_helper'

RSpec.describe StudentPeCalculationExercise, type: :model do
  subject { FactoryGirl.create :student_pe_calculation_exercise }

  it { is_expected.to belong_to :student_pe_calculation }

  it { is_expected.to validate_presence_of(:student_pe_calculation) }
  it { is_expected.to validate_presence_of(:exercise_uuid) }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid).scoped_to(:student_pe_calculation_uuid)
                                            .case_insensitive
    )
  end
end

require 'rails_helper'

RSpec.describe AlgorithmTeacherClueCalculation, type: :model do
  subject { FactoryGirl.create :algorithm_teacher_clue_calculation }

  it { is_expected.to belong_to(:teacher_clue_calculation) }

  it { is_expected.to validate_presence_of(:teacher_clue_calculation) }
  it { is_expected.to validate_presence_of(:algorithm_name) }
  it { is_expected.to validate_presence_of(:clue_data) }

  it do
    is_expected.to validate_uniqueness_of(:algorithm_name).scoped_to(:teacher_clue_calculation_uuid)
                                                          .case_insensitive
  end
end

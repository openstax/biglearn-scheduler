require 'rails_helper'

RSpec.describe AlgorithmStudentClueCalculation, type: :model do
  subject { FactoryBot.create :algorithm_student_clue_calculation }

  it { is_expected.to belong_to(:student_clue_calculation) }

  it { is_expected.to validate_presence_of(:algorithm_name) }
  it { is_expected.to validate_presence_of(:clue_data) }
  it { is_expected.to validate_presence_of(:clue_value) }

  it do
    is_expected.to validate_uniqueness_of(:algorithm_name).scoped_to(:student_clue_calculation_uuid)
                                                          .case_insensitive
  end
end

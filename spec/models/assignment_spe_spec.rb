require 'rails_helper'

RSpec.describe AssignmentSpe, type: :model do
  subject { FactoryBot.create :assignment_spe }

  it { is_expected.to belong_to :algorithm_exercise_calculation }
  it { is_expected.to belong_to :assignment }

  it { is_expected.to validate_presence_of :history_type  }
  it { is_expected.to validate_presence_of :exercise_uuid }

  it do
    is_expected.to(
      validate_uniqueness_of(:exercise_uuid)
        .scoped_to(:assignment_uuid, :algorithm_exercise_calculation_uuid, :history_type)
        .case_insensitive
    )
  end
end

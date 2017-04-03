require 'rails_helper'

RSpec.describe ExerciseCalculation, type: :model do
  subject { FactoryGirl.create :exercise_calculation }

  it { is_expected.to validate_presence_of :algorithm_uuid }
  it { is_expected.to validate_presence_of :exercise_uuids }
  it { is_expected.to validate_presence_of :student_uuids  }
end

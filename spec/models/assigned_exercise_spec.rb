require 'rails_helper'

RSpec.describe AssignedExercise, type: :model do
  subject { FactoryGirl.create :assigned_exercise }

  it { is_expected.to validate_presence_of(:assignment_uuid) }
  it { is_expected.to validate_presence_of(:exercise_uuid)   }
end

require 'rails_helper'

RSpec.describe Response, type: :model do
  subject { FactoryGirl.create :response }

  it { is_expected.to validate_presence_of :trial_uuid    }
  it { is_expected.to validate_presence_of :student_uuid  }
  it { is_expected.to validate_presence_of :exercise_uuid }
  it { is_expected.to validate_presence_of :responded_at  }
end

require 'rails_helper'

RSpec.describe Response, type: :model do
  subject { FactoryBot.create :response }

  it { is_expected.to belong_to(:student).optional             }

  it { is_expected.to belong_to(:exercise).optional            }

  it { is_expected.to belong_to(:assigned_exercise).optional   }

  it { is_expected.to validate_presence_of :ecosystem_uuid     }
  it { is_expected.to validate_presence_of :trial_uuid         }
  it { is_expected.to validate_presence_of :student_uuid       }
  it { is_expected.to validate_presence_of :exercise_uuid      }
  it { is_expected.to validate_presence_of :first_responded_at }
  it { is_expected.to validate_presence_of :last_responded_at  }
end

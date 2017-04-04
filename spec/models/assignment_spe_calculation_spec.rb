require 'rails_helper'

RSpec.describe AssignmentSpeCalculation, type: :model do
  subject { FactoryGirl.create :assignment_spe_calculation }

  it { is_expected.to validate_presence_of :ecosystem_uuid  }
  it { is_expected.to validate_presence_of :assignment_uuid }
  it { is_expected.to validate_presence_of :history_type    }
  it { is_expected.to validate_presence_of :student_uuid    }
  it { is_expected.to validate_presence_of :exercise_uuids  }

  it do
    is_expected.to validate_uniqueness_of(:k_ago)
                     .scoped_to(:assignment_uuid, :book_container_uuid, :history_type)
                     .case_insensitive
  end
end

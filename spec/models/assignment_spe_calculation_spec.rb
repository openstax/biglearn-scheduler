require 'rails_helper'

RSpec.describe AssignmentSpeCalculation, type: :model do
  subject { FactoryGirl.create :assignment_spe_calculation }

  it { is_expected.to have_many :assignment_spe_calculation_exercises }
  it { is_expected.to have_many :algorithm_assignment_spe_calculations }

  it { is_expected.to validate_presence_of :ecosystem_uuid  }
  it { is_expected.to validate_presence_of :assignment_uuid }
  it { is_expected.to validate_presence_of :history_type    }
  it { is_expected.to validate_presence_of :k_ago           }
  it { is_expected.to validate_presence_of :student_uuid    }
  it { is_expected.to validate_presence_of :exercise_uuids  }
  it { is_expected.to validate_presence_of :exercise_count  }

  it do
    is_expected.to validate_uniqueness_of(:is_spaced)
                     .scoped_to(:assignment_uuid, :book_container_uuid, :history_type, :k_ago)
  end

  it do
    is_expected.to validate_numericality_of(:k_ago)
                     .only_integer
                     .is_greater_than_or_equal_to(0)
  end
  it do
    is_expected.to validate_numericality_of(:exercise_count)
                     .only_integer
                     .is_greater_than_or_equal_to(0)
  end
end

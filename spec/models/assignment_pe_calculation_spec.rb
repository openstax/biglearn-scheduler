require 'rails_helper'

RSpec.describe AssignmentPeCalculation, type: :model do
  subject { FactoryGirl.create :assignment_pe_calculation }

  it { is_expected.to validate_presence_of :ecosystem_uuid      }
  it { is_expected.to validate_presence_of :assignment_uuid     }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :student_uuid        }
  it { is_expected.to validate_presence_of :exercise_uuids      }
  it { is_expected.to validate_presence_of :exercise_count      }

  it do
    is_expected.to(
      validate_uniqueness_of(:book_container_uuid).scoped_to(:assignment_uuid).case_insensitive
    )
  end
  it do
    is_expected.to validate_numericality_of(:exercise_count)
                     .only_integer
                     .is_greater_than_or_equal_to(0)
  end
end

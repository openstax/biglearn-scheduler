require 'rails_helper'

RSpec.describe StudentPeCalculation, type: :model do
  subject { FactoryGirl.create :student_pe_calculation }

  it { is_expected.to validate_presence_of :ecosystem_uuid      }
  it { is_expected.to validate_presence_of :student_uuid        }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :exercise_uuids      }

  it do
    is_expected.to(
      validate_uniqueness_of(:book_container_uuid).scoped_to(:student_uuid).case_insensitive
    )
  end
end

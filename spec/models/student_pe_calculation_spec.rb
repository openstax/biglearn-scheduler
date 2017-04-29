require 'rails_helper'

RSpec.describe StudentPeCalculation, type: :model do
  subject { FactoryGirl.create :student_pe_calculation }

  it { is_expected.to have_many :student_pe_calculation_exercises }
  it { is_expected.to have_many :algorithm_student_pe_calculations }

  it { is_expected.to validate_presence_of :clue_algorithm_name }
  it { is_expected.to validate_presence_of :ecosystem_uuid      }
  it { is_expected.to validate_presence_of :student_uuid        }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :exercise_uuids      }
  it { is_expected.to validate_presence_of :exercise_count      }

  it do
    is_expected.to(
      validate_uniqueness_of(:book_container_uuid).scoped_to(:student_uuid).case_insensitive
    )
  end
  it do
    is_expected.to validate_numericality_of(:exercise_count)
                     .only_integer
                     .is_greater_than_or_equal_to(0)
  end
end

require 'rails_helper'

RSpec.describe StudentClue, type: :model do
  subject { FactoryGirl.create :student_clue }

  it { is_expected.to validate_presence_of :student_uuid  }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :value  }

  it do
    is_expected.to(
      validate_uniqueness_of(:book_container_uuid).scoped_to(:student_uuid).case_insensitive
    )
  end

  it do
    is_expected.to(
      validate_numericality_of(:value).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1)
    )
  end
end

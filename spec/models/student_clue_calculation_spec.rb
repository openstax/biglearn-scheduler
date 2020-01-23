require 'rails_helper'

RSpec.describe StudentClueCalculation, type: :model do
  subject { FactoryBot.create :student_clue_calculation }

  it { is_expected.to have_many(:algorithm_student_clue_calculations).dependent(:destroy) }
  it { is_expected.to have_many(:ecosystem_exercises) }

  it { is_expected.to belong_to :student }

  it { is_expected.to validate_presence_of :ecosystem_uuid      }
  it { is_expected.to validate_presence_of :book_container_uuid }
  it { is_expected.to validate_presence_of :exercise_uuids      }
  it { is_expected.to validate_presence_of :responses           }

  it do
    is_expected.to(
      validate_uniqueness_of(:book_container_uuid).scoped_to(:student_uuid).case_insensitive
    )
  end
end

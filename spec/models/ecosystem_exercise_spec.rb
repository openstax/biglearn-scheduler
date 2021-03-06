require 'rails_helper'

RSpec.describe EcosystemExercise, type: :model do
  subject { FactoryBot.create :ecosystem_exercise }

  it { is_expected.to belong_to(:ecosystem) }
  it { is_expected.to belong_to(:exercise) }

  it { is_expected.to have_many(:responses) }
  it { is_expected.to have_many(:student_clue_calculations) }
  it { is_expected.to have_many(:teacher_clue_calculations) }

  it { is_expected.to validate_presence_of :book_container_uuids }

  it do
    is_expected.to(
      validate_uniqueness_of(:ecosystem_uuid).scoped_to(:exercise_uuid).case_insensitive
    )
  end
end

require 'rails_helper'

RSpec.describe EcosystemExercise, type: :model do
  subject { FactoryGirl.create :ecosystem_exercise }

  it { is_expected.to belong_to(:ecosystem) }
  it { is_expected.to belong_to(:exercise) }

  it { is_expected.to validate_presence_of :book_container_uuids }

  it do
    is_expected.to(
      validate_numericality_of(:next_ecosystem_matrix_update_response_count).only_integer.allow_nil
    )
  end
end

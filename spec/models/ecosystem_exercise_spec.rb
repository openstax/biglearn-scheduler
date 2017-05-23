require 'rails_helper'

RSpec.describe EcosystemExercise, type: :model do
  subject { FactoryGirl.create :ecosystem_exercise }

  it { is_expected.to belong_to(:exercise) }

  it { is_expected.to validate_presence_of :ecosystem_uuid }
  it { is_expected.to validate_presence_of :book_container_uuids }
end

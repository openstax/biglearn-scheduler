require 'rails_helper'

RSpec.describe EcosystemPreparation, type: :model do
  subject { FactoryBot.create :ecosystem_preparation }

  it { is_expected.to validate_presence_of :course_uuid }
  it { is_expected.to validate_presence_of :ecosystem_uuid }
end

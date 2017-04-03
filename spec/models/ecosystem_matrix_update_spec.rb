require 'rails_helper'

RSpec.describe EcosystemMatrixUpdate, type: :model do
  subject { FactoryGirl.create :ecosystem_matrix_update }

  it { is_expected.to validate_presence_of :algorithm_uuid }
  it { is_expected.to validate_presence_of :ecosystem_uuid }
end

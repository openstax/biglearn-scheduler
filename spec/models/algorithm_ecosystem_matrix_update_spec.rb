require 'rails_helper'

RSpec.describe AlgorithmEcosystemMatrixUpdate, type: :model do
  subject { FactoryGirl.create :algorithm_ecosystem_matrix_update }

  it { is_expected.to belong_to :ecosystem_matrix_update }

  it { is_expected.to validate_presence_of(:algorithm_name) }

  it do
    is_expected.to validate_uniqueness_of(:algorithm_name).scoped_to(:ecosystem_matrix_update_uuid)
                                                          .case_insensitive
  end
end

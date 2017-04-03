require 'rails_helper'

RSpec.describe EcosystemMatricesController, type: :routing do
  context "POST /fetch_ecosystem_matrix_updates" do
    it "routes to #fetch_ecosystem_matrix_updates" do
      expect(post '/fetch_ecosystem_matrix_updates').to(
        route_to('ecosystem_matrices#fetch_ecosystem_matrix_updates')
      )
    end
  end

  context "POST /ecosystem_matrices_updated" do
    it "routes to #ecosystem_matrices_updated" do
      expect(post '/ecosystem_matrices_updated').to(
        route_to('ecosystem_matrices#ecosystem_matrices_updated')
      )
    end
  end
end

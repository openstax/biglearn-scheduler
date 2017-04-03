require 'rails_helper'

RSpec.describe ClueCalculationsController, type: :routing do
  context "POST /fetch_clue_calculations" do
    it "routes to #fetch_clue_calculations" do
      expect(post '/fetch_clue_calculations').to(
        route_to('clue_calculations#fetch_clue_calculations')
      )
    end
  end

  context "POST /update_clue_calculations" do
    it "routes to #update_clue_calculations" do
      expect(post '/update_clue_calculations').to(
        route_to('clue_calculations#update_clue_calculations')
      )
    end
  end
end

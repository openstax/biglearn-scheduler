require 'rails_helper'

RSpec.describe ExerciseCalculationsController, type: :routing do
  context "POST /fetch_exercise_calculations" do
    it "routes to #fetch_exercise_calculations" do
      expect(post '/fetch_exercise_calculations').to(
        route_to('exercise_calculations#fetch_exercise_calculations')
      )
    end
  end

  context "POST /update_exercise_calculations" do
    it "routes to #update_exercise_calculations" do
      expect(post '/update_exercise_calculations').to(
        route_to('exercise_calculations#update_exercise_calculations')
      )
    end
  end
end

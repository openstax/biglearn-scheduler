Rails.application.routes.draw do
  scope controller: :exercise_calculations do
    post :fetch_exercise_calculations
    post :update_exercise_calculations
    post :fetch_algorithm_exercise_calculations
  end

  scope controller: :clue_calculations do
    post :fetch_clue_calculations
    post :update_clue_calculations
  end

  scope controller: :ecosystem_matrices do
    post :fetch_ecosystem_matrix_updates
    post :ecosystem_matrices_updated
  end
end

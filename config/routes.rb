Rails.application.routes.draw do
  post '/fetch_clue_calculations' => 'clue_calculations#fetch_clue_calculations'
  post '/update_clue_calculations' => 'clue_calculations#update_clue_calculations'

  post '/fetch_ecosystem_matrix_updates' => 'ecosystem_matrices#fetch_ecosystem_matrix_updates'
  post '/ecosystem_matrices_updated' => 'ecosystem_matrices#ecosystem_matrices_updated'

  post '/fetch_exercise_calculations' => 'exercise_calculations#fetch_exercise_calculations'
  post '/update_exercise_calculations' => 'exercise_calculations#update_exercise_calculations'
end

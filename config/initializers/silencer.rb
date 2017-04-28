require 'silencer/logger'

NOISY_POST_ACTIONS = [
  '/fetch_clue_calculations',
  '/fetch_ecosystem_matrix_updates',
  '/fetch_exercise_calculations'
]

Rails.application.configure do
  config.middleware.swap Rails::Rack::Logger, Silencer::Logger, post: NOISY_POST_ACTIONS
end

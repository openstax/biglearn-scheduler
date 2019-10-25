namespace :exercise_calculations do
  task cleanup: :environment do
    Services::CleanupExerciseCalculations::Service.process
  end
end

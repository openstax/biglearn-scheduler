namespace :exercise_calculations do
  task prepare: :environment do
    Services::PrepareExerciseCalculations::Service.process
  end
end

namespace :update_exercises do
  task practice_worst_areas: :environment do
    Services::UpdatePracticeWorstAreasExercises::Service.new.process
  end
end

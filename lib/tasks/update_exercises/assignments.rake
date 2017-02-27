namespace :update_exercises do
  task(assignments: :environment) { Services::UpdateAssignmentExercises::Service.new.process }
end

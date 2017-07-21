namespace :exercise_calculations do
  task upload_assignment: :environment do
    Services::UploadAssignmentExercises::Service.process
  end
end

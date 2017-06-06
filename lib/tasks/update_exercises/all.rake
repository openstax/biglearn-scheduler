namespace :update_exercises do
  task all: :environment do
    Services::PrepareExerciseCalculations::Service.process
    Services::UploadAssignmentExercises::Service.process
    Services::UploadStudentExercises::Service.process
  end
end

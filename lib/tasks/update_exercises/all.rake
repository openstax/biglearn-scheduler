namespace :update_exercises do
  task all: :environment do
    Services::PrepareExerciseCalculations::Service.new.process
    Services::UploadAssignmentExercises::Service.new.process
    Services::UploadStudentExercises::Service.new.process
  end
end

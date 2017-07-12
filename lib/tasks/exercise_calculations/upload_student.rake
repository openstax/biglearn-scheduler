namespace :exercise_calculations do
  task upload_student: :environment do
    Services::UploadStudentExercises::Service.process
  end
end

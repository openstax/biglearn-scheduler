namespace :update_exercises do
  task practice_worst_areas: :environment do
    Services::PrepareStudentExerciseCalculations::Service.new.process
    Services::UploadStudentPeCalculations::Service.new.process
  end
end

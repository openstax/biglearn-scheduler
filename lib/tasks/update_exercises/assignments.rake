namespace :update_exercises do
  task(assignments: :environment) do
    Services::PrepareExerciseCalculations::Service.new.process
    Services::UploadAssignmentPeCalculations::Service.new.process
    Services::UploadAssignmentSpeCalculations::Service.new.process
  end
end

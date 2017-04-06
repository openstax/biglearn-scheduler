namespace :update_clues do
  task(all: :environment) do
    Services::PrepareClueCalculations::Service.new.process
    Services::UploadStudentClueCalculations::Service.new.process
    Services::UploadTeacherClueCalculations::Service.new.process
  end
end

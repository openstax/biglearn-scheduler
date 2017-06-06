namespace :update_clues do
  task all: :environment do
    Services::PrepareClueCalculations::Service.process
    Services::UploadStudentClueCalculations::Service.process
    Services::UploadTeacherClueCalculations::Service.process
  end
end

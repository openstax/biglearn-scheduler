namespace :clue_calculations do
  task upload_teacher: :environment do
    Services::UploadTeacherClueCalculations::Service.process
  end
end

namespace :clue_calculations do
  task upload_student: :environment do
    Services::UploadStudentClueCalculations::Service.process
  end
end

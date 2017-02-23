namespace :update_clues do
  task(students: :environment) { Services::UpdateStudentClues::Service.new.process }
end

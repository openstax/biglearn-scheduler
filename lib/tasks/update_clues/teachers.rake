namespace :update_clues do
  task(teachers: :environment) { Services::UpdateTeacherClues::Service.new.process }
end

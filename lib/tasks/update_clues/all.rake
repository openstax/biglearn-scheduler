namespace :update_clues do
  task(all: :environment) { Services::UpdateClues::Service.new.process }
end

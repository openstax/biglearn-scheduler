namespace :clue_calculations do
  task prepare: :environment do
    Services::PrepareClueCalculations::Service.process
  end
end

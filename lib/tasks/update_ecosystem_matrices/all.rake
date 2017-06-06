namespace :update_ecosystem_matrices do
  task all: :environment do
    Services::PrepareEcosystemMatrixUpdates::Service.process
  end
end

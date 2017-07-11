namespace :ecosystem_matrix_updates do
  task prepare: :environment do
    Services::PrepareEcosystemMatrixUpdates::Service.process
  end
end

class AlgorithmEcosystemMatrixUpdate < ApplicationRecord
  validates :ecosystem_matrix_update_uuid, presence: true
  validates :algorithm_name,               presence: true,
                                           uniqueness: { scope: :ecosystem_matrix_update_uuid }
end

class AlgorithmEcosystemMatrixUpdate < ApplicationRecord
  belongs_to :ecosystem_matrix_update, primary_key: :uuid,
                                       foreign_key: :ecosystem_matrix_update_uuid,
                                       inverse_of: :algorithm_ecosystem_matrix_updates

  validates :ecosystem_matrix_update, presence: true
  validates :algorithm_name, presence: true, uniqueness: { scope: :ecosystem_matrix_update_uuid }
end

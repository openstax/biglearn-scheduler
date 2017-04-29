class EcosystemMatrixUpdate < ApplicationRecord
  has_many :algorithm_ecosystem_matrix_updates, primary_key: :uuid,
                                                foreign_key: :ecosystem_matrix_update_uuid,
                                                dependent: :destroy,
                                                inverse_of: :ecosystem_matrix_update

  validates :ecosystem_uuid, presence: true, uniqueness: true
end

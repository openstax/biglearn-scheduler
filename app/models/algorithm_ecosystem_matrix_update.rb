class AlgorithmEcosystemMatrixUpdate < ApplicationRecord
  belongs_to :ecosystem_matrix_update, primary_key: :uuid,
                                       foreign_key: :ecosystem_matrix_update_uuid,
                                       inverse_of: :algorithm_ecosystem_matrix_updates

  validates :algorithm_name, presence: true, uniqueness: { scope: :ecosystem_matrix_update_uuid }

  scope :unassociated, -> do
    where.not(
      EcosystemMatrixUpdate.where(
        '"uuid" = "algorithm_ecosystem_matrix_updates"."ecosystem_matrix_update_uuid"'
      ).exists
    )
  end
end

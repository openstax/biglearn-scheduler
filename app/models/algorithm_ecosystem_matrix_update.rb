class AlgorithmEcosystemMatrixUpdate < ApplicationRecord
  belongs_to :ecosystem_matrix_update, primary_key: :uuid,
                                       foreign_key: :ecosystem_matrix_update_uuid,
                                       inverse_of: :algorithm_ecosystem_matrix_updates

  unique_index :ecosystem_matrix_update_uuid, :algorithm_name, scoped_to: :ecosystem_matrix_update

  scope :unassociated, -> do
    where.not(
      EcosystemMatrixUpdate.where(
        '"uuid" = "algorithm_ecosystem_matrix_updates"."ecosystem_matrix_update_uuid"'
      ).arel.exists
    )
  end
end

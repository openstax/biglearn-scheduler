class EcosystemMatrixUpdate < ApplicationRecord
  validates :algorithm_uuid, presence: true
  validates :ecosystem_uuid, presence: true
end

class EcosystemMatrixUpdate < ApplicationRecord
  validates :algorithm_name, presence: true
  validates :ecosystem_uuid, presence: true
end

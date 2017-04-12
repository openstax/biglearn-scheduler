class EcosystemMatrixUpdate < ApplicationRecord
  validates :ecosystem_uuid, presence: true, uniqueness: true
end

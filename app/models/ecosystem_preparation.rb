class EcosystemPreparation < ApplicationRecord
  unique_index :uuid

  validates :course_uuid, presence: true
  validates :ecosystem_uuid, presence: true
end

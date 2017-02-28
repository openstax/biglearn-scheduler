class EcosystemPreparation < ApplicationRecord
  validates :course_uuid, presence: true
  validates :ecosystem_uuid, presence: true
end

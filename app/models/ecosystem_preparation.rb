class EcosystemPreparation < ActiveRecord::Base
  include HasUniqueUuid

  validates :course_uuid, presence: true
  validates :ecosystem_uuid, presence: true
end

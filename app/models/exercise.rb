class Exercise < ActiveRecord::Base
  include HasUniqueUuid

  validates :group_uuid, presence: true
  validates :version,    presence: true
end

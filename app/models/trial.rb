class Trial < ActiveRecord::Base
  include HasUniqueUuid

  validates :ecosystem_uuid, presence: true
end

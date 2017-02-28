class Exercise < ApplicationRecord
  validates :group_uuid, presence: true
  validates :version,    presence: true
end

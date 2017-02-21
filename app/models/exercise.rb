class Exercise < ActiveRecord::Base
  include HasUniqueUuid

  validates :exercise_uuid,       presence: true
  validates :group_uuid,          presence: true
  validates :version,             presence: true
  validates :exercise_pool_uuids, presence: true
end

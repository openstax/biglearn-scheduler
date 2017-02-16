class Exercise < ActiveRecord::Base
  include HasUniqueUuid

  validates :group_uuid,          presence: true
  validates :version,             presence: true,
                                  uniqueness: { scope: :group_uuid }
  validates :exercise_pool_uuids, presence: true
end

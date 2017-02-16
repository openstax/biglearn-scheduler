class Course < ActiveRecord::Base
  include HasUniqueUuid

  validates :sequence_number, presence: true,
                              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ecosystem_uuid,  presence: true
end

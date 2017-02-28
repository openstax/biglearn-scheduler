class BookContainerMapping < ActiveRecord::Base
  include HasUniqueUuid

  validates :uuid,                     presence: true
  validates :from_ecosystem_uuid,      presence: true
  validates :to_ecosystem_uuid,        presence: true
  validates :from_book_container_uuid, presence: true, uniqueness: { scope: [ :from_ecosystem_uuid,
                                                                              :to_ecosystem_uuid ] }
  validates :to_book_container_uuid,   presence: true
end

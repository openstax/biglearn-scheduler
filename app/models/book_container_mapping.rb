class BookContainerMapping < ApplicationRecord
  unique_index :from_book_container_uuid, :from_ecosystem_uuid, :to_ecosystem_uuid

  validates :to_book_container_uuid, presence: true
end

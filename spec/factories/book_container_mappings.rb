FactoryGirl.define do
  factory :book_container_mapping do
    uuid                     { SecureRandom.uuid }
    from_ecosystem_uuid      { SecureRandom.uuid }
    to_ecosystem_uuid        { SecureRandom.uuid }
    from_book_container_uuid { SecureRandom.uuid }
    to_book_container_uuid   { SecureRandom.uuid }
  end
end

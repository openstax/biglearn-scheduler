FactoryGirl.define do
  factory :trial do
    uuid           { SecureRandom.uuid }
    ecosystem_uuid { SecureRandom.uuid }
  end
end

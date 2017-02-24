FactoryGirl.define do
  factory :exercise do
    uuid       { SecureRandom.uuid }
    group_uuid { SecureRandom.uuid }
    version    { rand(10) + 1 }
  end
end

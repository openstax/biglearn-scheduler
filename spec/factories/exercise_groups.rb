FactoryGirl.define do
  factory :exercise_group do
    uuid           { SecureRandom.uuid }
    response_count 0
  end
end

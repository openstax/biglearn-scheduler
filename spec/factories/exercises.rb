FactoryGirl.define do
  factory :exercise do
    uuid           { SecureRandom.uuid }
    exercise_group
    version        { rand(10) + 1 }
  end
end

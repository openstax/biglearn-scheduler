FactoryGirl.define do
  factory :exercise do
    transient           { exercise_pools_count { rand(10) + 1 } }

    uuid                { SecureRandom.uuid }
    group_uuid          { SecureRandom.uuid }
    version             { rand(10) + 1 }
    exercise_pool_uuids { exercise_pools_count.times.map { SecureRandom.uuid } }
  end
end

FactoryGirl.define do
  factory :assignment_spe do
    uuid            { SecureRandom.uuid }
    student_uuid    { SecureRandom.uuid }
    assignment_uuid { SecureRandom.uuid }
    exercise_uuid   { SecureRandom.uuid }
    k_ago           { rand(5) + 1 }
  end
end

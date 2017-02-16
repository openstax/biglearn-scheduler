FactoryGirl.define do
  factory :assignment_spe do
    uuid            { SecureRandom.uuid }
    assignment_uuid { SecureRandom.uuid }
    exercise_uuid   { SecureRandom.uuid }
  end
end

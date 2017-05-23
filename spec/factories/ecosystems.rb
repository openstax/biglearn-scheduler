FactoryGirl.define do
  factory :ecosystem do
    uuid            { SecureRandom.uuid }
    sequence_number { rand(2) }
    exercise_uuids  { [] }
  end
end

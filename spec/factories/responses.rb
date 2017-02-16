FactoryGirl.define do
  factory :response do
    uuid          { SecureRandom.uuid }
    student_uuid  { SecureRandom.uuid }
    exercise_uuid { SecureRandom.uuid }
    is_correct    { [true, false].sample }
  end
end

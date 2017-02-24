FactoryGirl.define do
  factory :response do
    uuid          { SecureRandom.uuid }
    student_uuid  { SecureRandom.uuid }
    exercise_uuid { SecureRandom.uuid }
    responded_at  { DateTime.now }
    is_correct    { [true, false].sample }
    used_in_clues { [true, false].sample }
  end
end

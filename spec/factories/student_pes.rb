FactoryGirl.define do
  factory :student_pe do
    uuid          { SecureRandom.uuid }
    student_uuid  { SecureRandom.uuid }
    exercise_uuid { SecureRandom.uuid }
  end
end

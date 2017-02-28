FactoryGirl.define do
  factory :assignment_spe do
    uuid            { SecureRandom.uuid }
    assignment_uuid { SecureRandom.uuid }
    exercise_uuid   { SecureRandom.uuid }
    student_uuid    { SecureRandom.uuid }
  end
end

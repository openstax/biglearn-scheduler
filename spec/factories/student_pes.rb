FactoryGirl.define do
  factory :student_pe do
    uuid                           { SecureRandom.uuid }
    algorithm_exercise_calculation
    exercise_uuid                  { SecureRandom.uuid }
  end
end

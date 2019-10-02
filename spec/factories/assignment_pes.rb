FactoryBot.define do
  factory :assignment_pe do
    uuid                           { SecureRandom.uuid }
    algorithm_exercise_calculation
    assignment
    exercise_uuid                  { SecureRandom.uuid }
  end
end

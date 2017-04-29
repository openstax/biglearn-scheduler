FactoryGirl.define do
  factory :assignment_pe_calculation_exercise do
    uuid                      { SecureRandom.uuid }
    assignment_pe_calculation
    exercise_uuid             { SecureRandom.uuid }
  end
end

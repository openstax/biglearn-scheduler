FactoryGirl.define do
  factory :assignment_spe_calculation_exercise do
    uuid                       { SecureRandom.uuid }
    assignment_spe_calculation
    exercise_uuid              { SecureRandom.uuid }
  end
end

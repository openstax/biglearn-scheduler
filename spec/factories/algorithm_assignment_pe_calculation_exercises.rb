FactoryGirl.define do
  factory :algorithm_assignment_pe_calculation_exercise do
    uuid                                     { SecureRandom.uuid }
    algorithm_assignment_pe_calculation_uuid { SecureRandom.uuid }
    exercise_uuid                            { SecureRandom.uuid }
  end
end

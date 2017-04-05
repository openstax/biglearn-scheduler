FactoryGirl.define do
  factory :assignment_pe_calculation_exercise do
    uuid                           { SecureRandom.uuid }
    assignment_pe_calculation_uuid { SecureRandom.uuid }
    exercise_uuid                  { SecureRandom.uuid }
    assignment_uuid                { SecureRandom.uuid }
    student_uuid                   { SecureRandom.uuid }
  end
end

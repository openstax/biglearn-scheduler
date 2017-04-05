FactoryGirl.define do
  factory :assignment_spe_calculation_exercise do
    uuid                            { SecureRandom.uuid }
    assignment_spe_calculation_uuid { SecureRandom.uuid }
    exercise_uuid                   { SecureRandom.uuid }
    assignment_uuid                 { SecureRandom.uuid }
    student_uuid                    { SecureRandom.uuid }
  end
end

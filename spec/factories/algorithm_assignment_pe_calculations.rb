FactoryGirl.define do
  factory :algorithm_assignment_pe_calculation do
    uuid                           { SecureRandom.uuid }
    assignment_pe_calculation_uuid { SecureRandom.uuid }
    algorithm_name                 { [ 'local_query', 'tesr' ].sample }
    assignment_uuid                { SecureRandom.uuid }
    student_uuid                   { SecureRandom.uuid }
    exercise_uuids                 { [] }
    is_uploaded                    { [true, false].sample }
  end
end
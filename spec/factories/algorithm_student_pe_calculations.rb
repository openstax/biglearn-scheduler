FactoryGirl.define do
  factory :algorithm_student_pe_calculation do
    uuid                        { SecureRandom.uuid }
    student_pe_calculation_uuid { SecureRandom.uuid }
    algorithm_name              { [ 'local_query', 'tesr' ].sample }
    student_uuid                { SecureRandom.uuid }
    exercise_uuids              { [] }
    is_uploaded                 { [true, false].sample }
  end
end

FactoryGirl.define do
  factory :algorithm_assignment_spe_calculation do
    transient                       { num_exercise_uuids { rand(10) + 1 } }

    uuid                            { SecureRandom.uuid }
    assignment_spe_calculation_uuid { SecureRandom.uuid }
    algorithm_name                  { [ 'local_query', 'tesr' ].sample }
    assignment_uuid                 { SecureRandom.uuid }
    student_uuid                    { SecureRandom.uuid }
    exercise_uuids                  { num_exercise_uuids.times.map { SecureRandom.uuid } }
    is_uploaded                     { [true, false].sample }
  end
end

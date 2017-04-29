FactoryGirl.define do
  factory :algorithm_student_pe_calculation do
    transient              { num_exercise_uuids { rand(10) + 1 } }

    uuid                   { SecureRandom.uuid }
    student_pe_calculation
    algorithm_name         { [ 'local_query', 'tesr' ].sample }
    exercise_uuids         { num_exercise_uuids.times.map { SecureRandom.uuid } }
    is_uploaded            { [true, false].sample }
  end
end

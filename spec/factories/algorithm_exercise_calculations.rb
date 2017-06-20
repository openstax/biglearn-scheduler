FactoryGirl.define do
  factory :algorithm_exercise_calculation do
    transient                   { num_exercise_uuids { rand(10) + 1 } }

    uuid                        { SecureRandom.uuid }
    exercise_calculation
    algorithm_name              { [ 'local_query', 'tesr' ].sample }
    exercise_uuids              { num_exercise_uuids.times.map { SecureRandom.uuid } }
    is_uploaded_for_assignments { [ true, false ].sample }
    is_uploaded_for_student     { [ true, false ].sample }
  end
end

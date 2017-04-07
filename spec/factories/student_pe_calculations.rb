FactoryGirl.define do
  factory :student_pe_calculation do
    transient           { num_exercise_uuids { rand(10) + 1 } }

    uuid                { SecureRandom.uuid }
    clue_algorithm_name { [ 'local_query', 'sparfa' ].sample }
    ecosystem_uuid      { SecureRandom.uuid }
    student_uuid        { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    exercise_uuids      { num_exercise_uuids.times.map { SecureRandom.uuid } }
    exercise_count      { rand(num_exercise_uuids) + 1 }
  end
end
FactoryGirl.define do
  factory :assignment_spe_calculation do
    transient           { num_exercise_uuids { rand(10) + 1 } }

    uuid                { SecureRandom.uuid }
    ecosystem_uuid      { SecureRandom.uuid }
    assignment_uuid     { SecureRandom.uuid }
    history_type        { AssignmentSpeCalculation.history_types.keys.sample }
    k_ago               { rand(5) + 1 }
    book_container_uuid { SecureRandom.uuid }
    is_spaced           { [true, false].sample }
    student_uuid        { SecureRandom.uuid }
    exercise_uuids      { num_exercise_uuids.times.map { SecureRandom.uuid } }
    exercise_count      { rand(num_exercise_uuids) + 1 }
  end
end

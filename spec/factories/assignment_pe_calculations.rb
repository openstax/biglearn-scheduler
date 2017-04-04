FactoryGirl.define do
  factory :assignment_pe_calculation do
    transient           { num_exercise_uuids { rand(10) + 1 } }

    uuid                { SecureRandom.uuid }
    ecosystem_uuid      { SecureRandom.uuid }
    assignment_uuid     { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    student_uuid        { SecureRandom.uuid }
    exercise_uuids      { num_exercise_uuids.times.map { SecureRandom.uuid } }
  end
end

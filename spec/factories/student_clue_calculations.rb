FactoryGirl.define do
  factory :student_clue_calculation do
    transient           do
      num_exercise_uuids { rand(10) + 1 }
      num_response_uuids { rand(10) + 1 }
    end

    uuid                { SecureRandom.uuid }
    ecosystem_uuid      { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    student_uuid        { SecureRandom.uuid }
    exercise_uuids      { num_exercise_uuids.times.map { SecureRandom.uuid } }
    response_uuids      { num_response_uuids.times.map { SecureRandom.uuid } }
  end
end

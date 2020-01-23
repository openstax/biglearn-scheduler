FactoryBot.define do
  factory :student_clue_calculation do
    transient           do
      num_exercise_uuids { rand(10) + 1 }
      num_responses      { rand(10) + 1 }
    end

    uuid                { SecureRandom.uuid }
    student
    ecosystem_uuid      { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    exercise_uuids      { num_exercise_uuids.times.map { SecureRandom.uuid } }
    responses           do
      num_responses.times.map do
        {
          response_uuid: SecureRandom.uuid,
          trial_uuid: SecureRandom.uuid,
          is_correct: [true, false].sample
        }
      end
    end
  end
end

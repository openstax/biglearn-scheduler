FactoryGirl.define do
  factory :exercise_calculation do
    transient do
      num_exercise_uuids { rand(10) + 1 }
      num_student_uuids  { rand(10) + 1 }
    end

    uuid                   { SecureRandom.uuid }
    ecosystem_uuid         { SecureRandom.uuid }
    assignment_uuid        { SecureRandom.uuid }
    student_uuid           { SecureRandom.uuid }
    exercise_uuids         { num_exercise_uuids.times.map { SecureRandom.uuid } }
  end
end

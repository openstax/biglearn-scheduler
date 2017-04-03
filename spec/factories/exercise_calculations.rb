FactoryGirl.define do
  factory :exercise_calculation do
    transient do
      num_exercise_uuids { rand(10) + 1 }
      num_student_uuids  { rand(10) + 1 }
    end

    uuid                   { SecureRandom.uuid }
    algorithm_uuid         { SecureRandom.uuid }
    exercise_uuids         { num_exercise_uuids.times.map { SecureRandom.uuid } }
    student_uuids          { num_student_uuids.times.map  { SecureRandom.uuid } }
    is_calculated          { [true, false].sample }
    ordered_exercise_uuids { [] }
  end
end

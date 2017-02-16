FactoryGirl.define do
  factory :course do
    uuid                                 { SecureRandom.uuid }
    sequence_number                      { rand(1000) }
    ecosystem_uuid                       { SecureRandom.uuid }
    course_excluded_exercise_uuids       { [] }
    course_excluded_exercise_group_uuids { [] }
    global_excluded_exercise_uuids       { [] }
    global_excluded_exercise_group_uuids { [] }
  end
end

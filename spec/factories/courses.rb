FactoryGirl.define do
  factory :course do
    uuid                                 { SecureRandom.uuid }
    ecosystem_uuid                       { SecureRandom.uuid }
    sequence_number                      { rand(1000) }
    metadata_sequence_number             { (Course.maximum(:metadata_sequence_number) || -1) + 1 }
    course_excluded_exercise_uuids       { [] }
    course_excluded_exercise_group_uuids { [] }
    global_excluded_exercise_uuids       { [] }
    global_excluded_exercise_group_uuids { [] }
  end
end

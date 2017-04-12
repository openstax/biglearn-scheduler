FactoryGirl.define do
  factory :response do
    uuid                             { SecureRandom.uuid }
    ecosystem_uuid                   { SecureRandom.uuid }
    trial_uuid                       { SecureRandom.uuid }
    student_uuid                     { SecureRandom.uuid }
    exercise_uuid                    { SecureRandom.uuid }
    responded_at                     { Time.now }
    is_correct                       { [true, false].sample }
    used_in_clue_calculations        { [true, false].sample }
    used_in_ecosystem_matrix_updates { [true, false].sample }
  end
end

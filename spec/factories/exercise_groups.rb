FactoryGirl.define do
  factory :exercise_group do
    uuid                             { SecureRandom.uuid }
    response_count                   0
    used_in_ecosystem_matrix_updates { [true, false].sample }
  end
end

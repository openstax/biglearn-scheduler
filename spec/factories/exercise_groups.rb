FactoryGirl.define do
  factory :exercise_group do
    uuid                            { SecureRandom.uuid }
    response_count                  0
    next_update_response_count      1
    trigger_ecosystem_matrix_update { [ true, false ].sample }
  end
end

FactoryGirl.define do
  factory :algorithm_exercise_calculation do
    uuid                      { SecureRandom.uuid }
    exercise_calculation_uuid { SecureRandom.uuid }
    algorithm_name            { [ 'local_query', 'tesr' ].sample }
    exercise_uuids            { [] }
  end
end

FactoryGirl.define do
  factory :algorithm_clue_calculation do
    uuid                  { SecureRandom.uuid }
    clue_calculation_uuid { SecureRandom.uuid }
    algorithm_name        { [ 'local_query', 'sparfa' ].sample }
    clue_data             { {} }
  end
end

FactoryGirl.define do
  factory :algorithm_teacher_clue_calculation do
    uuid                          { SecureRandom.uuid }
    teacher_clue_calculation_uuid { SecureRandom.uuid }
    algorithm_name                { [ 'local_query', 'sparfa' ].sample }
    clue_data                     { { 'most_likely' => rand } }
  end
end

FactoryBot.define do
  factory :algorithm_teacher_clue_calculation do
    uuid                     { SecureRandom.uuid }
    teacher_clue_calculation
    algorithm_name           { [ 'local_query', 'sparfa' ].sample }
    clue_data                { { 'most_likely' => rand } }
    is_uploaded              { [true, false].sample }
  end
end

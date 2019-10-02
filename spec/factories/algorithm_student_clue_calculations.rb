FactoryBot.define do
  factory :algorithm_student_clue_calculation do
    uuid                     { SecureRandom.uuid }
    student_clue_calculation
    algorithm_name           { [ 'local_query', 'sparfa' ].sample }
    clue_data                { { 'most_likely' => clue_value } }
    clue_value               { rand }
    is_uploaded              { [true, false].sample }
  end
end

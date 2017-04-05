FactoryGirl.define do
  factory :algorithm_student_clue_calculation do
    uuid                          { SecureRandom.uuid }
    student_clue_calculation_uuid { SecureRandom.uuid }
    algorithm_name                { [ 'local_query', 'sparfa' ].sample }
    clue_data                     { { 'most_likely' => clue_value } }
    student_uuid                  { SecureRandom.uuid }
    clue_value                    { rand }
  end
end

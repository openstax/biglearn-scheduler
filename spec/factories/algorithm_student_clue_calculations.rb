FactoryGirl.define do
  factory :algorithm_student_clue_calculation do
    uuid                          { SecureRandom.uuid }
    student_clue_calculation_uuid { SecureRandom.uuid }
    algorithm_name                { [ 'local_query', 'sparfa' ].sample }
    clue_data                     { { 'most_likely' => clue_value } }
    is_uploaded                   { [true, false].sample }
    ecosystem_uuid                { SecureRandom.uuid }
    book_container_uuid           { SecureRandom.uuid }
    student_uuid                  { SecureRandom.uuid }
    clue_value                    { rand }
  end
end

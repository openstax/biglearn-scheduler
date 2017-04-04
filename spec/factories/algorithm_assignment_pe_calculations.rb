FactoryGirl.define do
  factory :algorithm_assignment_pe_calculation do
    uuid                           { SecureRandom.uuid }
    assignment_pe_calculation_uuid { SecureRandom.uuid }
    algorithm_name                 { [ 'local_query', 'tesr' ].sample }
  end
end

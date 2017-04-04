FactoryGirl.define do
  factory :algorithm_student_pe_calculation do
    uuid                        { SecureRandom.uuid }
    student_pe_calculation_uuid { SecureRandom.uuid }
    algorithm_name              { [ 'local_query', 'tesr' ].sample }
  end
end

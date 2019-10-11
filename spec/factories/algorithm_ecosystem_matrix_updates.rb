FactoryBot.define do
  factory :algorithm_ecosystem_matrix_update do
    uuid                    { SecureRandom.uuid }
    ecosystem_matrix_update
    algorithm_name          { [ 'local_query', 'biglearn_sparfa' ].sample }
  end
end

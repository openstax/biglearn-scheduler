FactoryGirl.define do
  factory :ecosystem_matrix_update do
    uuid           { SecureRandom.uuid }
    ecosystem_uuid { SecureRandom.uuid }
  end
end

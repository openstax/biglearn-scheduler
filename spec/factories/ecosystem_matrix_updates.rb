FactoryGirl.define do
  factory :ecosystem_matrix_update do
    uuid           { SecureRandom.uuid    }
    algorithm_name 'sparfa'
    ecosystem_uuid { SecureRandom.uuid    }
    is_updated     { [true, false].sample }
  end
end

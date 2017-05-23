FactoryGirl.define do
  factory :assigned_exercise do
    uuid           { SecureRandom.uuid    }
    assignment
    exercise_uuid  { SecureRandom.uuid    }
    is_spe         { [true, false].sample }
    is_pe          { [true, false].sample }
  end
end

FactoryGirl.define do
  factory :ecosystem do
    uuid                     { SecureRandom.uuid }
    sequence_number          { rand(2) }
    metadata_sequence_number { (Ecosystem.maximum(:metadata_sequence_number) || -1) + 1 }
    exercise_uuids           { [] }
  end
end

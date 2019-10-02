FactoryBot.define do
  factory :ecosystem_preparation do
    uuid           { SecureRandom.uuid }
    course_uuid    { SecureRandom.uuid }
    ecosystem_uuid { SecureRandom.uuid }
  end
end

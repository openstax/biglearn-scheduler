FactoryGirl.define do
  factory :response_clue do
    uuid        { SecureRandom.uuid }
    course_uuid { SecureRandom.uuid }
  end
end

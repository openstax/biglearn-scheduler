FactoryGirl.define do
  factory :assigned_exercise do
    uuid            { SecureRandom.uuid }
    assignment_uuid { SecureRandom.uuid }
  end
end

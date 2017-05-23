FactoryGirl.define do
  factory :exercise_calculation do
    uuid      { SecureRandom.uuid }
    ecosystem
    student
  end
end

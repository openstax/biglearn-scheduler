FactoryGirl.define do
  factory :student_clue do
    uuid                { SecureRandom.uuid }
    student_uuid        { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    value               { rand }
  end
end

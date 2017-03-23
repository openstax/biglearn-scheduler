FactoryGirl.define do
  factory :assignment_pe do
    uuid                { SecureRandom.uuid }
    student_uuid        { SecureRandom.uuid }
    assignment_uuid     { SecureRandom.uuid }
    book_container_uuid { SecureRandom.uuid }
    exercise_uuid       { SecureRandom.uuid }
  end
end

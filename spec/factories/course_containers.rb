FactoryGirl.define do
  factory :course_container do
    transient     { students_count { rand(10) } }

    uuid          { SecureRandom.uuid }
    course_uuid   { SecureRandom.uuid }
    student_uuids { students_count.times.map { SecureRandom.uuid } }
  end
end

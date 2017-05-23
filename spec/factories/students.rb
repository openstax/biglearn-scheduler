FactoryGirl.define do
  factory :student do
    transient              { course_containers_count { rand(10) + 1 } }

    uuid                   { SecureRandom.uuid }
    course
    course_container_uuids { course_containers_count.times.map { SecureRandom.uuid } }
  end
end

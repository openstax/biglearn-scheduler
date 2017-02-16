FactoryGirl.define do
  factory :exercise do
    transient            do
      book_containers_count { rand(10) + 1 }
      assignments_count     { rand(10) }
    end

    uuid                 { SecureRandom.uuid }
    group_uuid           { SecureRandom.uuid }
    version              { rand(10) + 1 }
    book_container_uuids { book_containers_count.times.map { SecureRandom.uuid } }
    assignment_uuids     { assignments_count.times.map { SecureRandom.uuid } }
  end
end

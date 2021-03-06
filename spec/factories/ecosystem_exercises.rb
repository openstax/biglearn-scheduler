FactoryBot.define do
  factory :ecosystem_exercise do
    transient            { book_containers_count { rand(10) + 1 } }

    uuid                 { SecureRandom.uuid }
    ecosystem
    exercise
    book_container_uuids { book_containers_count.times.map { SecureRandom.uuid } }
  end
end

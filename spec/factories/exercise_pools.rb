FactoryBot.define do
  factory :exercise_pool do
    transient                                 { exercises_count   { rand(10) } }

    uuid                                      { SecureRandom.uuid }
    ecosystem_uuid                            { SecureRandom.uuid }
    book_container_uuid                       { SecureRandom.uuid }
    use_for_clue                              { [true, false].sample }
    use_for_personalized_for_assignment_types do
      assignment_types = ['reading', 'homework', 'practice']
      assignment_types.sample(rand(assignment_types.size + 1))
    end
    exercise_uuids                            { exercises_count.times.map { SecureRandom.uuid } }
  end
end

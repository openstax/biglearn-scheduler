FactoryGirl.define do
  factory :assignment do
    transient                     do
      book_containers_count { rand(10) }
      exercises_count       { rand(10) }
    end

    uuid                          { SecureRandom.uuid }
    course_uuid                   { SecureRandom.uuid }
    ecosystem_uuid                { SecureRandom.uuid }
    student_uuid                  { SecureRandom.uuid }
    assignment_type               { ['reading', 'homework', 'practice', 'concept-coach'].sample }
    assigned_book_container_uuids { book_containers_count.times.map { SecureRandom.uuid } }
    assigned_exercise_uuids       { exercises_count.times.map { SecureRandom.uuid } }
    goal_num_tutor_assigned_spes  { rand(10) }
    spes_are_assigned             { [true, false].sample }
    goal_num_tutor_assigned_pes   { rand(10) }
    pes_are_assigned              { [true, false].sample }
  end
end

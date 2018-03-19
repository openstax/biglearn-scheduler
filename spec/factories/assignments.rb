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
    goal_num_tutor_assigned_spes  { [rand(10), nil].sample }
    spes_are_assigned             { [true, false].sample }
    goal_num_tutor_assigned_pes   { [rand(10), nil].sample }
    pes_are_assigned              { [true, false].sample }
    has_exercise_calculation      { [true, false].sample }

    after(:create) do |assignment|
      assigned_exercise_uuids = assignment.assigned_exercise_uuids
      num_spes = assignment.spes_are_assigned ? assignment.goal_num_tutor_assigned_spes || 0 : 0
      num_pes = assignment.pes_are_assigned ? assignment.goal_num_tutor_assigned_pes || 0 : 0
      first_spe_index = assigned_exercise_uuids.size - num_spes
      first_pe_index = first_spe_index - num_pes

      assigned_exercise_uuids.each_with_index do |assigned_exercise_uuid, index|
        create(
          :assigned_exercise,
          assignment: assignment,
          exercise_uuid: assigned_exercise_uuid,
          is_spe: index >= first_spe_index,
          is_pe: index >= first_pe_index && index < first_spe_index
        )
      end
    end
  end
end

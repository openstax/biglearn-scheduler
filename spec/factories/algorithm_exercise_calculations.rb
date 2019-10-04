FactoryBot.define do
  factory :algorithm_exercise_calculation do
    transient              { num_exercise_uuids { rand(10) + 1 } }

    uuid                   { SecureRandom.uuid }
    exercise_calculation
    algorithm_name         { [ 'local_query', 'biglearn_sparfa' ].sample }
    recommendation_uuid    { SecureRandom.uuid }
    exercise_uuids         { num_exercise_uuids.times.map { SecureRandom.uuid } }
    is_pending_for_student { [ true, false ].sample }

    after(:build) do |algorithm_exercise_calculation|
      algorithm_exercise_calculation.pending_assignment_uuids ||=
        algorithm_exercise_calculation.exercise_calculation.assignments.map(&:uuid)
    end
  end
end

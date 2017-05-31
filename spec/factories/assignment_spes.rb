FactoryGirl.define do
  factory :assignment_spe do
    uuid                           { SecureRandom.uuid }
    algorithm_exercise_calculation
    assignment
    exercise_uuid                  { SecureRandom.uuid }
    history_type                   { AssignmentSpe.history_types.keys.sample }
  end
end

FactoryBot.define do
  factory :exercise_calculation do
    uuid { SecureRandom.uuid }
    ecosystem
    student
    is_used_in_assignments { [ true, false ].sample }

    trait(:default) { student_uuid { ExerciseCalculation::DEFAULT_STUDENT_UUID } }
  end
end

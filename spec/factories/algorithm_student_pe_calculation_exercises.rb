FactoryGirl.define do
  factory :algorithm_student_pe_calculation_exercise do
    uuid                                  { SecureRandom.uuid }
    algorithm_student_pe_calculation_uuid { SecureRandom.uuid }
    exercise_uuid                         { SecureRandom.uuid }
    student_uuid                          { SecureRandom.uuid }
  end
end

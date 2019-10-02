FactoryBot.define do
  factory :response do
    transient                     { current_time { Time.current } }
    uuid                          { SecureRandom.uuid             }
    ecosystem_uuid                { SecureRandom.uuid             }
    trial_uuid                    { SecureRandom.uuid             }
    student_uuid                  { SecureRandom.uuid             }
    exercise_uuid                 { SecureRandom.uuid             }
    first_responded_at            { current_time                  }
    last_responded_at             { current_time                  }
    is_correct                    { [true, false].sample          }
    used_in_clue_calculations     { [true, false].sample          }
    used_in_exercise_calculations { [true, false].sample          }
    used_in_response_count        { [true, false].sample          }
    used_in_student_history       { [true, false].sample          }
  end
end

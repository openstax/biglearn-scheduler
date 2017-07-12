namespace :exercise_calculations do
  task update_student_history: :environment do
    Services::UpdateStudentHistory::Service.process
  end
end

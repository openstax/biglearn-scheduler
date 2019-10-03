include Tasks::ApplicationHelper

define_worker_tasks :'exercise_calculations:prepare'
define_worker_tasks :'exercise_calculations:update_student_history'
define_worker_tasks :'exercise_calculations:upload_assignment'
define_worker_tasks :'exercise_calculations:upload_student'
define_worker_tasks :'exercise_calculations:cleanup', 1.minute

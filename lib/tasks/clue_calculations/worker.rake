include Tasks::ApplicationHelper

define_worker_tasks :'clue_calculations:prepare'
define_worker_tasks :'clue_calculations:upload_student'
define_worker_tasks :'clue_calculations:upload_teacher'

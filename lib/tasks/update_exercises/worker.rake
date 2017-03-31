include Tasks::ApplicationHelper

namespace :update_exercises do
  define_worker_tasks :'update_exercises:all'
end

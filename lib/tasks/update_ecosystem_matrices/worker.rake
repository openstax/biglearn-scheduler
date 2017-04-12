include Tasks::ApplicationHelper

namespace :update_ecosystem_matrices do
  define_worker_tasks :'update_ecosystem_matrices:all'
end

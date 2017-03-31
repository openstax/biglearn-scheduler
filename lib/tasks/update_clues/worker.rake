include Tasks::ApplicationHelper

namespace :update_clues do
  define_worker_tasks :'update_clues:all'
end

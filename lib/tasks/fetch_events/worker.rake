include Tasks::ApplicationHelper

namespace :fetch_events do
  define_worker_tasks :'fetch_events:all'
end

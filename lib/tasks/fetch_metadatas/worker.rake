include Tasks::ApplicationHelper

namespace :fetch_metadatas do
  define_worker_tasks :'fetch_metadatas:all'
end

class ApplicationJob < ActiveJob::Base
  queue_as :default

  def perform_with_transaction(*args)
    fail NotImplementedError
  end

  def perform(*args)
    ActiveRecord::Base.transaction { perform_with_transaction *args }
  end
end

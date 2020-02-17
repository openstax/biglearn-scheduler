# Defaults:
# Delayed::Worker.destroy_failed_jobs = true
# Delayed::Worker.sleep_delay = 5
# Delayed::Worker.max_attempts = 25
# Delayed::Worker.max_run_time = 4.hours
# Delayed::Worker.read_ahead = 5
# Delayed::Worker.default_queue_name = nil
# Delayed::Worker.delay_jobs = true
# Delayed::Worker.raise_signal_exceptions = false
# Delayed::Worker.logger = Rails.logger

# Keep failed jobs for later inspection
Delayed::Worker.destroy_failed_jobs = false

# Poll the database every second to reduce delay (number of workers = number of queries per second)
Delayed::Worker.sleep_delay = 1

# Default queue name if not specified in the job class
Delayed::Worker.default_queue_name = :default

# Allows us to use this gem in tests instead of setting the ActiveJob adapter to :inline
Delayed::Worker.delay_jobs = Rails.env.production? || (
  Rails.env.development? && ENV['USE_REAL_BACKGROUND_JOBS']
)

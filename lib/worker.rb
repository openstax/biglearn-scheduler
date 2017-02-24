class Worker
  def initialize(task)
    @task = task
    @task_string = task.to_s
  end

  def run
    log(:debug) { 'Executing task...' }
    Rake::Task[@task].execute
  end

  def start(run_every = 1.second)
    start_time = Time.now.freeze
    log(:info) { "Started at #{start_time}" }

    1.upto(Float::INFINITY).each do |iteration|
      run

      wake_up_at = start_time + iteration * run_every
      sleep_interval = wake_up_at - Time.now
      if sleep_interval > 0
        log(:debug) { "#{sleep_interval} second(s) ahead of schedule - sleeping..." }
        sleep sleep_interval
      else
        log(:debug) { "#{-sleep_interval} second(s) behind schedule - skipping sleep" }
      end
    end
  end

  protected

  def log(level, &block)
    Rails.logger.tagged(@task_string, 'Worker') { |logger| logger.public_send(level, &block) }
  end
end

module Tasks
  module ApplicationHelper
    DAEMON_COMMANDS = [:start, :stop, :restart, :reload, :run, :zap, :status]

    protected

    # http://stackoverflow.com/a/10823131
    def sanitize_filename(filename)
      # Split the name when finding a period which is preceded by some
      # character, and is followed by some character other than a period,
      # if there is no following period that is followed by something
      # other than a period (yeah, confusing, I know)
      fn = filename.to_s.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m

      # We now have one or two parts (depending on whether we could find
      # a suitable period). For each of these parts, replace any unwanted
      # sequence of characters with an underscore
      fn = fn.map { |s| s.gsub /[^a-z0-9\-]+/i, '_' }

      # Finally, join the parts with a period and return the result
      fn.join '.'
    end

    def get_daemon_options(sanitized_task_name, args)
      logfilename = ENV['LOG_FILENAME'] || "#{sanitized_task_name}.log"

      {
        dir: File.expand_path(ENV['PID_DIR'] || 'tmp'),
        log_dir: File.expand_path(ENV['LOG_DIR'] || 'log'),
        logfilename: logfilename,
        ARGV: args.to_a
      }
    end

    def run_daemon(task_name, args, run_every)
      task_name_string = task_name.to_s
      sanitized_task_name = sanitize_filename(task_name_string)
      options = get_daemon_options(sanitized_task_name, args)

      Daemons.run_proc(sanitized_task_name, options) do
        log_file = File.join options[:log_dir], options[:logfilename]
        logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(log_file)
        logger.formatter = Rails.application.config.log_formatter
        logger.level = Rails.application.config.log_level
        Rails.logger = logger
        ActiveRecord::Base.logger = logger
        ActionController::Base.logger = logger
        ActionView::Base.logger = logger
        ActionMailer::Base.logger = logger
        Raven.configuration.logger = logger

        # Don't send SystemExit to Sentry
        OpenStax::RescueFrom.register_exception(
          SystemExit,
          status: :service_unavailable,
          notify: false
        )

        Worker.new(task_name_string).run run_every
      end
    end

    def define_worker_tasks(task_name, run_every = 1.second, worker_task_suffix = :worker)
      task "#{task_name}:#{worker_task_suffix}" => :environment do |task, args|
        run_daemon task_name, args, run_every
      end

      DAEMON_COMMANDS.each do |command|
        task "#{task_name}:#{worker_task_suffix}:#{command}" => :environment do |task, args|
          run_daemon task_name, [command.to_s] + args.to_a, run_every
        end
      end
    end
  end
end

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

    def get_daemon_options(sanitized_task_name, args_array)
      logfilename = ENV['LOG_FILENAME'] || "#{sanitized_task_name}.log"
      current_dir = Dir.pwd

      {
        dir_mode: :script,
        dir: File.join(current_dir, ENV['PID_DIR'] || 'tmp'),
        log_dir: File.join(current_dir, ENV['LOG_DIR'] || 'log'),
        logfilename: logfilename,
        multiple: false,
        ontop: false,
        backtrace: true,
        monitor: false,
        ARGV: args_array
      }
    end

    def define_worker_tasks(task_name, worker_task_prefix = :worker)
      task_name_string = task_name.to_s
      sanitized_task_name = sanitize_filename(task_name_string)
      daemon_proc = ->(args) do
        options = get_daemon_options(sanitized_task_name, args)
        Daemons.run_proc(sanitized_task_name, options) do
          log_file = File.join options[:log_dir], options[:logfilename]
          logger = ActiveSupport::Logger.new log_file
          logger.formatter = Rails.application.config.log_formatter
          Rails.logger = ActiveSupport::TaggedLogging.new logger

          Worker.new(task_name_string).run
        end
      end

      task(worker_task_prefix => :environment) { |task, args| daemon_proc.call args.to_a }

      DAEMON_COMMANDS.each do |command|
        task("#{worker_task_prefix}:#{command}" => :environment) do |task, args|
          daemon_proc.call [command.to_s] + args.to_a
        end
      end
    end
  end
end
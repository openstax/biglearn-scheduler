namespace :fetch_metadatas do
  task worker: :environment do
    FETCH_METADATAS_EVERY = 1.second.freeze
    START_TIME = Time.now.freeze
    Rails.logger.info { "Fetch metadatas worker started at #{START_TIME}" }

    1.upto(Float::INFINITY).each do |iteration|
      Rake::Task['fetch_metadatas:all'].execute

      wake_up_at = START_TIME + iteration * FETCH_METADATAS_EVERY
      sleep_interval = wake_up_at - Time.now
      if sleep_interval > 0
        Rails.logger.debug { "#{sleep_interval} second(s) ahead of schedule - sleeping..." }
        sleep sleep_interval
      else
        Rails.logger.debug { "#{-sleep_interval} second(s) behind schedule - skipping sleep" }
      end
    end
  end
end

class Services::FetchEcosystemMatrixUpdates::Service
  def process(algorithm_uuid:)
    start_time = Time.now
    Rails.logger.tagged 'FetchEcosystemMatrixUpdates' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    Rails.logger.tagged 'FetchEcosystemMatrixUpdates' do |logger|
      # logger.info do
      #   course_events = course_event_responses.map do |response|
      #     response.fetch(:events).size
      #   end.reduce(0, :+)
      #   conflicts = results.map { |result| result.failed_instances.size }.reduce(0, :+)
      #   time = Time.now - start_time
      #
      #   "Received: #{course_events} event(s) in #{courses.size} course(s)" +
      #   " - Conflicts: #{conflicts} - Took: #{time} second(s)"
      # end
    end
  end
end

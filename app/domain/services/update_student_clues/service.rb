class Services::UpdateStudentClues::Service
  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdateStudentClues' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Any responses updated after the last CLUe update indicate the need for a new CLUe
    

    Rails.logger.tagged 'UpdateStudentClues' do |logger|
      logger.info do
        metadatas = courses.size
        conflicts = result.failed_instances.size
        successes = metadatas - conflicts
        total = Course.count
        time = Time.now - start_time

        "Received: #{metadatas} - Existing: #{conflicts} - New: #{successes}" +
        " - Total: #{total} - Took: #{time} second(s)"
      end
    end
  end
end

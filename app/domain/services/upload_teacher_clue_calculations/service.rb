class Services::UploadTeacherClueCalculations::Service
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadTeacherClueCalculations' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmTeacherClueCalculation.transaction do
        # sent_to_api_server tracks the status of each calculation
        algorithm_calculations = AlgorithmTeacherClueCalculation.where(sent_to_api_server: false)
                                                                .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_calculations|
          next if num_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:teacher_clue_calculation_uuid)
          calculations_by_uuid = TeacherClueCalculation.where(uuid: calculation_uuids)
                                                       .index_by(&:uuid)

          teacher_clue_requests = algorithm_calculations.map do |algorithm_calculation|
            calculation_uuid = algorithm_calculation.teacher_clue_calculation_uuid
            calculation = calculations_by_uuid[calculation_uuid]
            if calculation.nil?
              Rails.logger.tagged 'UploadTeacherClueCalculations' do |logger|
                logger.warn do
                  "Teacher CLUe skipped due to no information about teacher CLUe calculation #{
                    calculation_uuid
                  }"
                end
              end

              next
            end

            {
              algorithm_name: algorithm_calculation.algorithm_name,
              course_container_uuid: calculation.course_container_uuid,
              book_container_uuid: calculation.book_container_uuid,
              clue_data: algorithm_calculation.clue_data
            }
          end.compact

          OpenStax::Biglearn::Api.update_teacher_clues(teacher_clue_requests) \
            if teacher_clue_requests.any?

          algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
          AlgorithmTeacherClueCalculation.where(uuid: algorithm_calculation_uuids)
                                         .update_all(sent_to_api_server: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadTeacherClueCalculations' do |logger|
      logger.info do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

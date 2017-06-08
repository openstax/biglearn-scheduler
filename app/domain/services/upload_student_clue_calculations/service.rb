class Services::UploadStudentClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadStudentClueCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmStudentClueCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmStudentClueCalculation.where(is_uploaded: false)
                                                                .lock('FOR UPDATE SKIP LOCKED')
                                                                .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_calculations|
          next if num_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:student_clue_calculation_uuid)
          calculations_by_uuid = StudentClueCalculation.where(uuid: calculation_uuids)
                                                       .index_by(&:uuid)

          student_clue_requests = algorithm_calculations.map do |algorithm_calculation|
            calculation_uuid = algorithm_calculation.student_clue_calculation_uuid
            calculation = calculations_by_uuid[calculation_uuid]
            if calculation.nil?
              Rails.logger.tagged 'UploadStudentClueCalculations' do |logger|
                logger.warn do
                  "Student CLUe skipped due to no information about student CLUe calculation #{
                    calculation_uuid
                  }"
                end
              end

              next
            end

            {
              algorithm_name: algorithm_calculation.algorithm_name,
              student_uuid: calculation.student_uuid,
              book_container_uuid: calculation.book_container_uuid,
              clue_data: algorithm_calculation.clue_data
            }
          end.compact

          OpenStax::Biglearn::Api.update_student_clues(student_clue_requests) \
            if student_clue_requests.any?

          algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
          AlgorithmStudentClueCalculation.where(uuid: algorithm_calculation_uuids)
                                         .update_all(is_uploaded: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadStudentClueCalculations' do |logger|
      logger.debug do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

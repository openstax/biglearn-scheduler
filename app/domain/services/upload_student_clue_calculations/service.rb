class Services::UploadStudentClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmStudentClueCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        # join is used so AlgorithmStudentClueCalculations
        # with no StudentClueCalculation are not returned
        # eager_load is used because it's basically free with the join
        algorithm_calculations = AlgorithmStudentClueCalculation
          .joins(:student_clue_calculation)
          .eager_load(:student_clue_calculation)
          .where(is_uploaded: false)
          .lock('FOR NO KEY UPDATE OF "algorithm_student_clue_calculations" SKIP LOCKED')
          .take(BATCH_SIZE)

        student_clue_requests = algorithm_calculations.map do |algorithm_calculation|
          calculation = algorithm_calculation.student_clue_calculation

          {
            algorithm_name: algorithm_calculation.algorithm_name,
            student_uuid: calculation.student_uuid,
            book_container_uuid: calculation.book_container_uuid,
            clue_data: algorithm_calculation.clue_data
          }
        end.compact

        OpenStax::Biglearn::Api.update_student_clues(student_clue_requests) \
          unless student_clue_requests.empty?

        algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
        AlgorithmStudentClueCalculation.where(uuid: algorithm_calculation_uuids)
                                       .update_all(is_uploaded: true)

        algorithm_calculations.size
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    log(:debug) do
      "#{total_calculations} calculation(s) uploaded in #{Time.current - start_time} second(s)"
    end
  end
end

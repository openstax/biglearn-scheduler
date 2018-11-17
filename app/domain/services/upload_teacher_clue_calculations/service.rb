class Services::UploadTeacherClueCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmTeacherClueCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        # join is used so AlgorithmTeacherClueCalculations
        # with no TeacherClueCalculation are not returned
        # eager_load is used because it's basically free with the join
        # No order needed because of SKIP LOCKED
        algorithm_calculations = AlgorithmTeacherClueCalculation
          .joins(:teacher_clue_calculation)
          .eager_load(:teacher_clue_calculation)
          .where(is_uploaded: false)
          .lock('FOR NO KEY UPDATE OF "algorithm_teacher_clue_calculations" SKIP LOCKED')
          .take(BATCH_SIZE)
        algorithm_calculations_size = algorithm_calculations.size
        next 0 if algorithm_calculations_size == 0

        teacher_clue_requests = algorithm_calculations.map do |algorithm_calculation|
          calculation = algorithm_calculation.teacher_clue_calculation

          {
            algorithm_name: algorithm_calculation.algorithm_name,
            course_container_uuid: calculation.course_container_uuid,
            book_container_uuid: calculation.book_container_uuid,
            clue_data: algorithm_calculation.clue_data
          }
        end.compact

        OpenStax::Biglearn::Api.update_teacher_clues(teacher_clue_requests) \
          unless teacher_clue_requests.empty?

        algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
        # No order needed because already locked above
        AlgorithmTeacherClueCalculation.where(uuid: algorithm_calculation_uuids)
                                       .update_all(is_uploaded: true)

        algorithm_calculations_size
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

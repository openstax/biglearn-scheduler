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
        algorithm_calculations = AlgorithmTeacherClueCalculation
          .where(is_uploaded: false)
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
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
              log(:warn) do
                "Teacher CLUe skipped due to no information about teacher CLUe calculation #{
                  calculation_uuid
                }"
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
                                         .update_all(is_uploaded: true)
        end
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

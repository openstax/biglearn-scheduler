class Services::UploadStudentPeCalculations::Service
  BATCH_SIZE = 1000

  # TODO: In the future we could allow Tutor to pick any combination of algorithms
  # But for now we hardcode the allowed combinations
  ALLOWED_ALGORITHM_COMBINATIONS = [ [ 'sparfa', 'tesr' ], [ 'local_query', 'local_query' ] ]

  # TODO: Because these exercises are used in practice assignments,
  # exclude exercises we plan to assign (to real assignments) from the list of exercises
  # Reason:
  # If the assignment receiving the SPEs/PEs is a practice assignment,
  # we consider planned exercises as if they were already assigned to prevent
  # students from practicing all exercises and getting all the answers ahead of time
  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmStudentPeCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmStudentPeCalculation.where(is_uploaded: false)
                                                              .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_calculations|
          next if num_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:student_pe_calculation_uuid)
          calculations_by_uuid = StudentPeCalculation.where(uuid: calculation_uuids)
                                                     .index_by(&:uuid)

          practice_worst_areas_requests = algorithm_calculations.map do |algorithm_calculation|
            calculation_uuid = algorithm_calculation.student_pe_calculation_uuid
            calculation = calculations_by_uuid[calculation_uuid]
            if calculation.nil?
              Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
                logger.warn do
                  "Student PE skipped due to no information about student PE calculation #{
                    calculation_uuid
                  }"
                end
              end

              next
            end

            pe_algorithm = algorithm_calculation.algorithm_name
            clue_algorithm = calculation.clue_algorithm_name
            next unless ALLOWED_ALGORITHM_COMBINATIONS.include? [ clue_algorithm, pe_algorithm ]

            {
              algorithm_name: algorithm_calculation.algorithm_name,
              student_uuid: calculation.student_uuid,
              exercise_uuids: algorithm_calculation.exercise_uuids.first(calculation.exercise_count)
            }
          end.compact

          OpenStax::Biglearn::Api.update_practice_worst_areas(practice_worst_areas_requests) \
            if practice_worst_areas_requests.any?

          algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
          AlgorithmStudentPeCalculation.where(uuid: algorithm_calculation_uuids)
                                       .update_all(is_uploaded: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
      logger.info do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

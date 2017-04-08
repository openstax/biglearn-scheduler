class Services::UploadAssignmentPeCalculations::Service
  BATCH_SIZE = 1000

  # TODO: For practice assignments, exclude exercises we plan to assign (to real assignments)
  # from the list of exercises
  # Reason:
  # If the assignment receiving the SPEs/PEs is a practice assignment,
  # we remove exercises we plan to assign to open non-practice assignments to prevent
  # students from practicing all exercises and getting all the answers ahead of time
  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadAssignmentPeCalculations' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmAssignmentPeCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmAssignmentPeCalculation.where(is_uploaded: false)
                                                                 .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_calculations|
          next if num_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:assignment_pe_calculation_uuid)
          calculations_by_uuid = AssignmentPeCalculation.where(uuid: calculation_uuids)
                                                        .index_by(&:uuid)

          assignment_pe_requests = algorithm_calculations.map do |algorithm_calculation|
            calculation_uuid = algorithm_calculation.assignment_pe_calculation_uuid
            calculation = calculations_by_uuid[calculation_uuid]
            if calculation.nil?
              Rails.logger.tagged 'UploadAssignmentPeCalculations' do |logger|
                logger.warn do
                  "Assignment PE skipped due to no information about assignment PE calculation #{
                    calculation_uuid
                  }"
                end
              end

              next
            end

            {
              algorithm_name: algorithm_calculation.algorithm_name,
              assignment_uuid: calculation.assignment_uuid,
              exercise_uuids: algorithm_calculation.exercise_uuids.first(calculation.exercise_count)
            }
          end.compact

          OpenStax::Biglearn::Api.update_assignment_pes(assignment_pe_requests) \
            if assignment_pe_requests.any?

          algorithm_calculation_uuids = algorithm_calculations.map(&:uuid)
          AlgorithmAssignmentPeCalculation.where(uuid: algorithm_calculation_uuids)
                                          .update_all(is_uploaded: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadAssignmentPeCalculations' do |logger|
      logger.info do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

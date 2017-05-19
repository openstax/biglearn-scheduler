class Services::UploadAssignmentSpeCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadAssignmentSpeCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    aaspec = AlgorithmAssignmentSpeCalculation.arel_table
    aspec = AssignmentSpeCalculation.arel_table
    aapec = AlgorithmAssignmentPeCalculation.arel_table
    apec = AssignmentPeCalculation.arel_table

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmAssignmentSpeCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmAssignmentSpeCalculation
          .with_assignment_spe_calculation_attributes(aaspec[:is_uploaded].eq(false))
          .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_algorithm_calculations|
          next if num_algorithm_calculations == 0

          assignment_uuids = algorithm_calculations.map(&:assignment_uuid)

          # If assigning PEs to a practice assignment, exclude any exercises that we plan to
          # assign to open non-practice assignments to prevent students from practicing
          # and getting all the answers ahead of time

          # Find the uuids of the practice assignments
          practice_assignment_uuids = Set.new(
            Assignment.where(uuid: assignment_uuids, assignment_type: 'practice').pluck(:uuid)
          )

          # Find the calculations that refer to practice assignments
          practice_algorithm_calculations = algorithm_calculations.select do |calc|
            practice_assignment_uuids.include? calc.assignment_uuid
          end

          if practice_algorithm_calculations.any?
            # Find assignment calculations for the same algorithms and students
            aaspec_queries = []
            aapec_queries = []
            practice_algorithm_calculations.each do |calc|
              aaspec_queries << aaspec[:algorithm_name].eq(calc.algorithm_name).and(
                                  aspec[:history_type].eq(calc.history_type).and(
                                    aspec[:student_uuid].eq(calc.student_uuid)
                                  )
                                )

              aapec_queries << aapec[:algorithm_name].eq(calc.algorithm_name).and(
                                 apec[:student_uuid].eq(calc.student_uuid)
                               )
            end
            aaspec_query = aaspec_queries.reduce(:or)
            aapec_query = aapec_queries.reduce(:or)
            aaspe_calcs = AlgorithmAssignmentSpeCalculation
                            .with_assignment_spe_calculation_attributes(aaspec_query)
            aape_calcs = AlgorithmAssignmentPeCalculation
                           .with_assignment_pe_calculation_attributes(aapec_query)

            # Find assignments associated with these algorithm calculations
            aa_calcs = aaspe_calcs + aape_calcs
            assignment_uuids = aa_calcs.map(&:assignment_uuid)
            assignments_by_uuid = Assignment.where(uuid: assignment_uuids)
                                            .pluck(:uuid, :assignment_type, :due_at)
                                            .index_by(&:first)

            # The exercises in the calculations for assignments
            # that are not yet due may not be used in practice assignments
            practice_excluded_ex_uuids_by_s_uuid_alg_name_and_history_type = Hash.new do |hash, key|
              hash[key] = Hash.new do |hash, key|
                hash[key] = Hash.new { |hash, key| hash[key] = [] }
              end
            end
            aa_calcs.each do |calc|
              assignment = assignments_by_uuid[calc.assignment_uuid]

              next if assignment.nil? ||
                      assignment.second == 'practice' ||
                      assignment.third.nil? ||
                      assignment.third <= start_time

              student_uuid = calc.student_uuid
              alg_name = calc.algorithm_name
              exercise_uuids = calc.exercise_uuids.first(calc.exercise_count)
              history_type = calc.respond_to?(:history_type) ? calc.history_type : 'all'

              practice_excluded_ex_uuids_by_s_uuid_and_alg_name \
                [student_uuid][alg_name][history_type].concat exercise_uuids
            end
          end

          # Calculations may have been split into multiple parts to fit the scheduler API
          # Gather the parts needed to reconstruct the result to be sent to biglearn-api
          # Assignment SPE calculations are partitioned by algorithm, assignment, history_type,
          # k_ago and book_container_uuid and combined by algorithm, assignment and history_type
          # before sending
          aaspec_query = algorithm_calculations.map do |calc|
            aaspec[:algorithm_name].eq(calc.algorithm_name).and(
              aspec[:assignment_uuid].eq(calc.assignment_uuid).and(
                aspec[:history_type].eq(calc.history_type)
              )
            )
          end.compact.reduce(:or)
          rel_aaspe_calcs_by_assignment_uuid_alg_name_and_history_type = Hash.new do |hash, key|
            hash[key] = Hash.new do |hash, key|
              hash[key] = Hash.new { |hash, key| hash[key] = [] }
            end
          end
          rel_aaspe_calcs = AlgorithmAssignmentSpeCalculation
                             .with_assignment_spe_calculation_attributes(aaspec_query)
          rel_aaspe_calcs.each do |calc|
            assignment_uuid = calc.assignment_uuid
            algorithm_name = calc.algorithm_name
            history_type = calc.history_type

            rel_aaspe_calcs_by_assignment_uuid_alg_name_and_history_type \
              [assignment_uuid][algorithm_name][history_type] << calc
          end

          assignment_spe_requests = rel_aaspe_calcs_by_assignment_uuid_alg_name_and_history_type
            .flat_map do |assignment_uuid, rel_aaspe_calcs_by_alg_name_and_history_type|
            # Remove any exercises that are planned to be assigned to open non-practice
            # assignments for the same student and algorithm
            excluded_ex_uuids_by_alg_name_and_history_type = Hash.new do |hash, key|
              hash[key] = Hash.new { |hash, key| hash[key] = [] }
            end
            if practice_assignment_uuids.include?(assignment_uuid)
              student_uuids = rel_aaspe_calcs_by_alg_name_and_history_type.values
                                                                          .map(&:values)
                                                                          .flatten
                                                                          .map(&:student_uuid)
                                                                          .uniq

              practice_excluded_ex_uuids_by_s_uuid_alg_name_and_history_type
                .values_at(*student_uuids)
                .each do |practice_excluded_ex_uuids_by_alg_name_and_history_type|
                practice_excluded_ex_uuids_by_alg_name_and_history_type
                  .each do |alg_name, practice_excluded_ex_uuids_by_history_type|
                  practice_excluded_ex_uuids_by_history_type
                    .each do |history_type, practice_excluded_ex_uuids|
                    excluded_ex_uuids_by_alg_name_and_history_type[alg_name][history_type] +=
                      practice_excluded_ex_uuids
                  end
                end
              end
            end

            rel_aaspe_calcs_by_alg_name_and_history_type
              .flat_map do |alg_name, rel_aaspe_calcs_by_history_type|
              excluded_ex_uuids_by_history_type =
                excluded_ex_uuids_by_alg_name_and_history_type[alg_name]

              rel_aaspe_calcs_by_history_type.map do |history_type, rel_aaspe_calcs|
                excluded_exercise_uuids = excluded_ex_uuids_by_history_type[history_type] +
                                          excluded_ex_uuids_by_history_type['all']

                exercise_uuids = rel_aaspe_calcs.flat_map do |calc|
                  allowed_exercise_uuids = calc.exercise_uuids - excluded_exercise_uuids
                  allowed_exercise_uuids.first(calc.exercise_count).tap do |chosen_exercises|
                    # Avoid repeats (could happen due to multiple k-ago slots not existing)
                    excluded_exercise_uuids += chosen_exercises
                  end
                end

                # TODO: Eventually we want to use algorithm_uuids instead of algorithm_names
                #       This code will potentially be an edge case for that change:
                history_type_string = AssignmentSpeCalculation.history_types.key(history_type)
                algorithm_name = [alg_name, history_type_string].join('_')

                {
                  algorithm_name: algorithm_name,
                  assignment_uuid: assignment_uuid,
                  exercise_uuids: exercise_uuids
                }
              end
            end
          end

          # Send calculations to biglearn-api
          OpenStax::Biglearn::Api.update_assignment_spes(assignment_spe_requests) \
            if assignment_spe_requests.any?

          # Mark calculations as uploaded
          AlgorithmAssignmentSpeCalculation.where(id: rel_aaspe_calcs.ids)
                                           .update_all(is_uploaded: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadAssignmentSpeCalculations' do |logger|
      logger.debug do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

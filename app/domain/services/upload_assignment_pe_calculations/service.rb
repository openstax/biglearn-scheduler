class Services::UploadAssignmentPeCalculations::Service
  BATCH_SIZE = 1000

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

        algorithm_calculations.size.tap do |num_algorithm_calculations|
          next if num_algorithm_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:assignment_pe_calculation_uuid)
          calculations = AssignmentPeCalculation.where(uuid: calculation_uuids)
          assignment_uuids = calculations.map(&:assignment_uuid)

          # If assigning PEs to a practice assignment, exclude any exercises that we plan to
          # assign to open non-practice assignments to prevent students from practicing
          # and getting all the answers ahead of time

          # Get the uuids of the practice assignments
          assignment_uuids = calculations.map(&:assignment_uuid)
          practice_assignment_uuids = Set.new(
            Assignment.where(uuid: assignment_uuids, assignment_type: 'practice').pluck(:uuid)
          )

          # Get calculations for practice assignments
          practice_algorithm_calculations = algorithm_calculations.select do |alg_calc|
            practice_assignment_uuids.include? alg_calc.assignment_uuid
          end

          if practice_algorithm_calculations.any?
            # Find other assignment calculations for the same algorithms and students
            aaspec = AlgorithmAssignmentSpeCalculation.arel_table
            aapec = AlgorithmAssignmentPeCalculation.arel_table
            aaspec_queries = []
            aapec_queries = []
            practice_algorithm_calculations.each do |alg_calc|
              aaspec_queries << aaspec[:algorithm_name].eq(alg_calc.algorithm_name).and(
                                  aaspec[:student_uuid].eq(alg_calc.student_uuid)
                                )

              aapec_queries << aapec[:algorithm_name].eq(alg_calc.algorithm_name).and(
                                 aapec[:student_uuid].eq(alg_calc.student_uuid)
                               )
            end
            aaspec_query = aaspec_queries.reduce(:or)
            aapec_query = aapec_queries.reduce(:or)
            other_alg_spe_calcs = AlgorithmAssignmentSpeCalculation.where(aaspec_query)
            other_alg_pe_calcs = AlgorithmAssignmentPeCalculation.where(aapec_query)

            # Find assignments associated with these algorithm calculations
            other_alg_calcs = other_alg_spe_calcs + other_alg_pe_calcs
            other_assignment_uuids = other_alg_calcs.map(&:assignment_uuid)
            other_assignments_by_uuid = Assignment.where(uuid: other_assignment_uuids)
                                                  .pluck(:uuid, :assignment_type, :due_at)
                                                  .index_by(&:first)

            # Keep only non-practice calculations for assignments that are not yet due
            open_non_practice_alg_spe_calcs = other_alg_spe_calcs.select do |alg_calc|
              assignment = other_assignments_by_uuid[alg_calc.assignment_uuid]
              next if assignment.nil?

              assignment.second != 'practice' && assignment.third > start_time
            end
            open_non_practice_alg_pe_calcs = other_alg_pe_calcs.select do |alg_calc|
              assignment = other_assignments_by_uuid[alg_calc.assignment_uuid]
              next if assignment.nil?

              assignment.second != 'practice' && assignment.third > start_time
            end

            # Find the calculations associated with the remaining algorithm calculations
            open_non_practice_spe_calc_uuids = open_non_practice_alg_spe_calcs
                                                 .map(&:assignment_spe_calculation_uuid)
            open_non_practice_spe_calcs_by_uuid = AssignmentSpeCalculation
                                                    .where(uuid: open_non_practice_spe_calc_uuids)
                                                    .index_by(&:uuid)
            open_non_practice_pe_calc_uuids = open_non_practice_alg_pe_calcs
                                                .map(&:assignment_pe_calculation_uuid)
            open_non_practice_pe_calcs_by_uuid = AssignmentPeCalculation
                                                   .where(uuid: open_non_practice_pe_calc_uuids)
                                                   .index_by(&:uuid)

            # The exercises in the remaining calculations may not be used in practice assignments
            practice_excluded_ex_uuids_by_alg_name_and_s_uuid = Hash.new do |hash, key|
              hash[key] = Hash.new { |hash, key| hash[key] = [] }
            end
            open_non_practice_alg_spe_calcs.each do |alg_calc|
              calc = open_non_practice_spe_calcs_by_uuid[alg_calc.assignment_spe_calculation_uuid]
              next if calc.nil?

              student_uuid = alg_calc.student_uuid
              algorithm_name = alg_calc.algorithm_name
              exercise_uuids = alg_calc.exercise_uuids.first(calc.exercise_count)

              practice_excluded_ex_uuids_by_alg_name_and_s_uuid[algorithm_name][student_uuid].concat
                exercise_uuids
            end
            open_non_practice_alg_pe_calcs.each do |alg_calc|
              calc = open_non_practice_pe_calcs_by_uuid[alg_calc.assignment_pe_calculation_uuid]
              next if calc.nil?

              student_uuid = alg_calc.student_uuid
              algorithm_name = alg_calc.algorithm_name
              exercise_uuids = alg_calc.exercise_uuids.first(calc.exercise_count)

              practice_excluded_ex_uuids_by_alg_name_and_s_uuid[algorithm_name][student_uuid].concat
                exercise_uuids
            end
          end

          # Calculations may have been split into multiple parts to fit the scheduler API
          # Gather the parts needed to reconstruct the result to be sent to biglearn-api
          # Assignment PE calculations are partitioned by algorithm, assignment and
          # book_container_uuid and combined by algorithm and assignment before sending
          related_calculations = AssignmentPeCalculation.where(assignment_uuid: assignment_uuids)
          related_calcs_by_uuid = related_calculations.index_by(&:uuid)
          related_calcs_by_assignment_uuid = related_calculations.group_by(&:assignment_uuid)
          aapec = AlgorithmAssignmentPeCalculation.arel_table
          aapec_queries = algorithm_calculations.map do |alg_calc|
            related_calcs = related_calcs_by_assignment_uuid[alg_calc.assignment_uuid] || []

            aapec[:algorithm_name].eq(alg_calc.algorithm_name).and(
              aapec[:assignment_pe_calculation_uuid].in(related_calcs.map(&:uuid))
            )
          end.compact.reduce(:or)
          related_alg_calcs_by_assignment_uuid_and_alg_name = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
          related_algorithm_calculations = AlgorithmAssignmentPeCalculation.where(aapec_queries)
          related_algorithm_calculations.each do |alg_calc|
            assignment_uuid = alg_calc.assignment_uuid
            algorithm_name = alg_calc.algorithm_name

            related_alg_calcs_by_assignment_uuid_and_alg_name[assignment_uuid][algorithm_name] <<
              alg_calc
          end

          assignment_pe_requests = related_alg_calcs_by_assignment_uuid_and_alg_name
            .flat_map do |assignment_uuid, related_alg_calcs_by_alg_name|
            related_alg_calcs_by_alg_name.map do |alg_name, related_alg_calcs|
              if practice_assignment_uuids.include?(assignment_uuid)
                practice_excluded_ex_uuids_by_s_uuid =
                  practice_excluded_ex_uuids_by_alg_name_and_s_uuid[alg_name]
              else
                practice_excluded_ex_uuids_by_s_uuid = {}
              end

              exercise_uuids = related_alg_calcs.flat_map do |alg_calc|
                calc_uuid = alg_calc.assignment_pe_calculation_uuid
                calc = related_calcs_by_uuid[calc_uuid]
                if calc.nil?
                  # Something bad happened like a race condition or manual assignment deletion
                  Rails.logger.tagged 'UploadAssignmentPeCalculations' do |logger|
                    logger.warn do
                      "Assignment PE skipped due to no information" +
                      " about assignment PE calculation #{calc_uuid}"
                    end
                  end

                  next []
                end

                # Remove any exercises that are planned to be assigned to open non-practice
                # assignments for the same algorithm and student
                student_uuid = alg_calc.student_uuid
                excluded_exercise_uuids = practice_excluded_ex_uuids_by_s_uuid[student_uuid] || []

                allowed_exercise_uuids = alg_calc.exercise_uuids - excluded_exercise_uuids
                allowed_exercise_uuids.first(calc.exercise_count)
              end

              {
                algorithm_name: alg_name,
                assignment_uuid: assignment_uuid,
                exercise_uuids: exercise_uuids
              }
            end
          end

          # Send calculations to biglearn-api
          OpenStax::Biglearn::Api.update_assignment_pes(assignment_pe_requests) \
            if assignment_pe_requests.any?

          # Mark calculations as uploaded
          related_algorithm_calculations.update_all(is_uploaded: true)
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

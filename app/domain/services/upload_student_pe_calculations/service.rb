class Services::UploadStudentPeCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  # TODO: In the future we could allow Tutor to pick any combination of algorithms
  # (by adding the clue_algorithm_name to the PracticeWorstAreas API in biglearn-api)
  # But for now we hardcode the allowed combinations
  ALLOWED_ALGORITHM_COMBINATIONS = [ [ 'sparfa', 'tesr' ], [ 'local_query', 'local_query' ] ]

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    astpec = AlgorithmStudentPeCalculation.arel_table
    stpec = StudentPeCalculation.arel_table
    aaspec = AlgorithmAssignmentSpeCalculation.arel_table
    aspec = AssignmentSpeCalculation.arel_table
    aapec = AlgorithmAssignmentPeCalculation.arel_table
    apec = AssignmentPeCalculation.arel_table

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmStudentPeCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmStudentPeCalculation
          .with_student_pe_calculation_attributes(astpec[:is_uploaded].eq(false))
          .lock
          .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_algorithm_calculations|
          next if num_algorithm_calculations == 0

          # Since these PEs always go to practice assignments, exclude any exercises that we plan to
          # assign to open non-practice assignments to prevent students from practicing
          # and getting all the answers ahead of time

          # Find assignment calculations for the same algorithms and students
          aaspec_queries = []
          aapec_queries = []
          algorithm_calculations.each do |calc|
            aaspec_queries << aaspec[:algorithm_name].eq(calc.algorithm_name).and(
                                aspec[:student_uuid].eq(calc.student_uuid)
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
          # that are not yet due may not be used in this service
          excluded_ex_uuids_by_s_uuid_and_alg_name = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
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

            excluded_ex_uuids_by_s_uuid_and_alg_name[student_uuid][alg_name].concat exercise_uuids
          end

          # Calculations may have been split into multiple parts to fit the scheduler API
          # Gather the parts needed to reconstruct the result to be sent to biglearn-api
          # Student PE calculations are partitioned by clue algorithm, algorithm, student and
          # book_container_uuid and combined by clue algorithm, algorithm and student before sending
          astpec_query = algorithm_calculations.map do |calc|
            stpec[:clue_algorithm_name].eq(calc.clue_algorithm_name).and(
              astpec[:algorithm_name].eq(calc.algorithm_name).and(
                stpec[:student_uuid].eq(calc.student_uuid)
              )
            )
          end.compact.reduce(:or)
          rel_aspe_calcs_by_student_uuid_alg_name_and_clue_alg_name = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = [] } }
          end
          rel_aspe_calcs = AlgorithmStudentPeCalculation
                             .with_student_pe_calculation_attributes(astpec_query)
          rel_aspe_calcs.each do |calc|
            student_uuid = calc.student_uuid
            algorithm_name = calc.algorithm_name
            clue_algorithm_name = calc.clue_algorithm_name

            rel_aspe_calcs_by_student_uuid_alg_name_and_clue_alg_name \
              [student_uuid][algorithm_name][clue_algorithm_name] << calc
          end

          worst_areas_requests = rel_aspe_calcs_by_student_uuid_alg_name_and_clue_alg_name
            .flat_map do |student_uuid, rel_aspe_calcs_by_alg_name_and_clue_alg_name|
            # Exclude any exercises that are planned to be assigned to open non-practice
            # assignments for the same student and algorithm
            excluded_ex_uuids_by_alg_name = excluded_ex_uuids_by_s_uuid_and_alg_name[student_uuid]

            rel_aspe_calcs_by_alg_name_and_clue_alg_name
              .flat_map do |alg_name, rel_aspe_calcs_by_clue_alg_name|
              rel_aspe_calcs_by_clue_alg_name.map do |clue_alg_name, rel_aspe_calcs|
                next unless ALLOWED_ALGORITHM_COMBINATIONS.include? [ clue_alg_name, alg_name ]

                excluded_exercise_uuids = excluded_ex_uuids_by_alg_name[alg_name] || []

                exercise_uuids = rel_aspe_calcs.flat_map do |calc|
                  allowed_exercise_uuids = calc.exercise_uuids - excluded_exercise_uuids
                  allowed_exercise_uuids.first(calc.exercise_count).tap do |chosen_exercises|
                    # Avoid repeats
                    # (could happen if one of the worst areas book_containers contains another)
                    excluded_exercise_uuids += chosen_exercises
                  end
                end

                {
                  algorithm_name: alg_name,
                  student_uuid: student_uuid,
                  exercise_uuids: exercise_uuids
                }
              end.compact
            end
          end

          # Send calculations to biglearn-api
          OpenStax::Biglearn::Api.update_practice_worst_areas(worst_areas_requests) \
            if worst_areas_requests.any?

          # Mark calculations as uploaded
          AlgorithmStudentPeCalculation.where(id: rel_aspe_calcs.ids).update_all(is_uploaded: true)
        end
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_calculations += num_calculations
      break if num_calculations < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
      logger.debug do
        "#{total_calculations} calculation(s) uploaded in #{Time.now - start_time} second(s)"
      end
    end
  end
end

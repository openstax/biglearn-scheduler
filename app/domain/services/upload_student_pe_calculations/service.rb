class Services::UploadStudentPeCalculations::Service
  BATCH_SIZE = 1000

  # TODO: In the future we could allow Tutor to pick any combination of algorithms
  # (by adding the clue_algorithm_name to the PracticeWorstAreas API in biglearn-api)
  # But for now we hardcode the allowed combinations
  ALLOWED_ALGORITHM_COMBINATIONS = [ [ 'sparfa', 'tesr' ], [ 'local_query', 'local_query' ] ]

  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadAssignmentSpeCalculations' do |logger|
      logger.info { "Started at #{start_time}" }
    end

    # Do all the processing in batches to not exceed the API limit
    total_calculations = 0
    loop do
      num_calculations = AlgorithmStudentPeCalculation.transaction do
        # is_uploaded tracks the status of each calculation
        algorithm_calculations = AlgorithmStudentPeCalculation.where(is_uploaded: false)
                                                                 .take(BATCH_SIZE)

        algorithm_calculations.size.tap do |num_algorithm_calculations|
          next if num_algorithm_calculations == 0

          calculation_uuids = algorithm_calculations.map(&:student_pe_calculation_uuid)
          calculations = StudentPeCalculation.where(uuid: calculation_uuids)
          student_uuids = calculations.map(&:student_uuid)

          # Since these PEs always go to practice assignments, exclude any exercises that we plan to
          # assign to open non-practice assignments to prevent students from practicing
          # and getting all the answers ahead of time

          # Find assignment calculations for the same algorithms and students
          aaspec = AlgorithmAssignmentSpeCalculation.arel_table
          aapec = AlgorithmAssignmentPeCalculation.arel_table
          aaspec_queries = []
          aapec_queries = []
          algorithm_calculations.each do |alg_calc|
            aaspec_queries << aaspec[:algorithm_name].eq(alg_calc.algorithm_name).and(
                                aaspec[:student_uuid].eq(alg_calc.student_uuid)
                              )

            aapec_queries << aapec[:algorithm_name].eq(alg_calc.algorithm_name).and(
                               aapec[:student_uuid].eq(alg_calc.student_uuid)
                             )
          end
          aaspec_query = aaspec_queries.reduce(:or)
          aapec_query = aapec_queries.reduce(:or)
          alg_assignment_spe_calcs = AlgorithmAssignmentSpeCalculation.where(aaspec_query)
          alg_assignment_pe_calcs = AlgorithmAssignmentPeCalculation.where(aapec_query)

          # Find assignments associated with these algorithm calculations
          alg_assignment_calcs = alg_assignment_spe_calcs + alg_assignment_pe_calcs
          assignment_uuids = alg_assignment_calcs.map(&:assignment_uuid)
          assignments_by_uuid = Assignment.where(uuid: assignment_uuids)
                                          .pluck(:uuid, :assignment_type, :due_at)
                                          .index_by(&:first)

          # Keep only non-practice calculations for assignments that are not yet due
          open_non_practice_alg_spe_calcs = alg_assignment_spe_calcs.select do |alg_calc|
            assignment = assignments_by_uuid[alg_calc.assignment_uuid]
            next if assignment.nil?

            assignment.second != 'practice' && assignment.third > start_time
          end
          open_non_practice_alg_pe_calcs = alg_assignment_pe_calcs.select do |alg_calc|
            assignment = assignments_by_uuid[alg_calc.assignment_uuid]
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

          # The exercises in the remaining calculations may not be used in this service
          excluded_ex_uuids_by_s_uuid_and_alg_name = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
          open_non_practice_alg_spe_calcs.each do |alg_calc|
            calc = open_non_practice_spe_calcs_by_uuid[alg_calc.assignment_spe_calculation_uuid]
            next if calc.nil?

            student_uuid = alg_calc.student_uuid
            alg_name = alg_calc.algorithm_name
            exercise_uuids = alg_calc.exercise_uuids.first(calc.exercise_count)

            excluded_ex_uuids_by_s_uuid_and_alg_name[student_uuid][alg_name].concat exercise_uuids
          end
          open_non_practice_alg_pe_calcs.each do |alg_calc|
            calc = open_non_practice_pe_calcs_by_uuid[alg_calc.assignment_pe_calculation_uuid]
            next if calc.nil?

            student_uuid = alg_calc.student_uuid
            alg_name = alg_calc.algorithm_name
            exercise_uuids = alg_calc.exercise_uuids.first(calc.exercise_count)

            excluded_ex_uuids_by_s_uuid_and_alg_name[student_uuid][alg_name].concat exercise_uuids
          end

          # Calculations may have been split into multiple parts to fit the scheduler API
          # Gather the parts needed to reconstruct the result to be sent to biglearn-api
          # Student PE calculations are partitioned by clue algorithm, algorithm, student and
          # book_container_uuid and combined by clue algorithm, algorithm and student before sending
          related_calculations = StudentPeCalculation.where(student_uuid: student_uuids)
          related_calcs_by_uuid = related_calculations.index_by(&:uuid)
          related_calcs_by_student_uuid = related_calculations.group_by(&:student_uuid)
          aspec = AlgorithmStudentPeCalculation.arel_table
          aspec_queries = algorithm_calculations.map do |alg_calc|
            related_calcs = related_calcs_by_student_uuid[alg_calc.student_uuid] || []

            aspec[:algorithm_name].eq(alg_calc.algorithm_name).and(
              aspec[:student_pe_calculation_uuid].in(related_calcs.map(&:uuid))
            )
          end.compact.reduce(:or)
          related_alg_calcs_by_student_uuid_alg_name_and_clue_alg_name = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = [] } }
          end
          related_algorithm_calculations = AlgorithmStudentPeCalculation.where(aspec_queries)
          related_algorithm_calculations.each do |alg_calc|
            student_uuid = alg_calc.student_uuid
            algorithm_name = alg_calc.algorithm_name
            calc = related_calcs_by_uuid[alg_calc.student_pe_calculation_uuid]
            clue_algorithm_name = calc.clue_algorithm_name

            related_alg_calcs_by_student_uuid_alg_name_and_clue_alg_name \
              [student_uuid][algorithm_name][clue_algorithm_name] << alg_calc
          end

          worst_areas_requests = related_alg_calcs_by_student_uuid_alg_name_and_clue_alg_name
            .flat_map do |student_uuid, related_alg_calcs_by_alg_name_and_clue_alg_name|
            # Remove any exercises that are planned to be assigned to open non-practice
            # assignments for the same algorithm and student
            excluded_exercise_uuids_by_algorithm_name =
              excluded_ex_uuids_by_s_uuid_and_alg_name[student_uuid]

            related_alg_calcs_by_alg_name_and_clue_alg_name
              .flat_map do |alg_name, related_alg_calcs_by_clue_alg_name|
              related_alg_calcs_by_clue_alg_name.map do |clue_alg_name, related_alg_calcs|
                next unless ALLOWED_ALGORITHM_COMBINATIONS.include? [ clue_alg_name, alg_name ]

                excluded_exercise_uuids = excluded_exercise_uuids_by_algorithm_name[alg_name] || []

                exercise_uuids = related_alg_calcs.flat_map do |alg_calc|
                  calc_uuid = alg_calc.student_pe_calculation_uuid
                  calc = related_calcs_by_uuid[calc_uuid]
                  if calc.nil?
                    # Something bad happened like a race condition or manual student deletion
                    Rails.logger.tagged 'UploadStudentPeCalculations' do |logger|
                      logger.warn do
                        "Student PE skipped due to no information" +
                        " about student PE calculation #{calc_uuid}"
                      end
                    end

                    next []
                  end

                  allowed_exercise_uuids = alg_calc.exercise_uuids - excluded_exercise_uuids
                  allowed_exercise_uuids.first(calc.exercise_count)
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
          related_algorithm_calculations.update_all(is_uploaded: true)
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

class Services::UploadAssignmentExercises::Service < Services::ApplicationService
  include AssignmentExerciseRequests

  BATCH_SIZE = 10

  MAX_K_AGO = K_AGOS_TO_LOAD.max

  # NOTE: We don't support partial PE/SPE assignments,
  # we create all of them for each assignment in one go
  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    aa = Assignment.arel_table
    ec = ExerciseCalculation.arel_table
    aec = AlgorithmExerciseCalculation.arel_table
    ape = AssignmentPe.arel_table
    aspe = AssignmentSpe.arel_table

    total_algorithm_exercise_calculations = 0
    loop do
      num_algorithm_exercise_calculations = AlgorithmExerciseCalculation.transaction do
        # Find algorithm_exercise_calculations with assignments that need PEs or SPEs
        # No order needed because of SKIP LOCKED
        algorithm_exercise_calculations = AlgorithmExerciseCalculation
          .where('CARDINALITY("algorithm_exercise_calculations"."pending_assignment_uuids") > 0')
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .take(BATCH_SIZE)
        algorithm_exercise_calculations_size = algorithm_exercise_calculations.size
        next 0 if algorithm_exercise_calculations_size == 0

        algorithm_exercise_calculations_by_uuid = algorithm_exercise_calculations.index_by(&:uuid)
        algorithm_exercise_calculation_uuids = algorithm_exercise_calculations_by_uuid.keys

        all_assignments = Assignment
          .select(
            <<~SELECT_SQL
              DISTINCT ON ("assignments"."uuid", "algorithm_exercise_calculations"."algorithm_name")
                "assignments".*,
                "algorithm_exercise_calculations"."uuid" AS "algorithm_exercise_calculation_uuid"
            SELECT_SQL
          )
          .joins(exercise_calculations: :algorithm_exercise_calculations)
          .where(uuid: algorithm_exercise_calculations.flat_map(&:pending_assignment_uuids))
          .where(
            exercise_calculations: {
              algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids }
            }
          )
          .order(aa[:uuid], aec[:algorithm_name], ec[:superseded_at].desc)
        assignments = all_assignments.to_a.uniq

        # Delete relevant AssignmentPe and AssignmentSpes, since we are about to reupload them
        pe_assignments = assignments.select(&:needs_pes?)
        unless pe_assignments.empty?
          assignment_pe_values = pe_assignments.map do |pe_assignment|
            [ pe_assignment.uuid, pe_assignment.algorithm_exercise_calculation_uuid ]
          end
          assignment_pe_where_query = <<~WHERE_SQL
            "assignment_pes"."id" IN (
              SELECT "assignment_pes"."id"
              FROM "assignment_pes"
              INNER JOIN (#{ValuesTable.new(assignment_pe_values)}) AS "values"
                ("assignment_uuid", "algorithm_exercise_calculation_uuid")
                ON "assignment_pes"."assignment_uuid" = "values"."assignment_uuid"::uuid
                AND "assignment_pes"."algorithm_exercise_calculation_uuid" =
                  "values"."algorithm_exercise_calculation_uuid"::uuid
            )
          WHERE_SQL
          AssignmentPe.where(assignment_pe_where_query).ordered_delete_all
        end
        spe_assignments = assignments.select(&:needs_spes?)
        unless spe_assignments.empty?
          assignment_spe_values = spe_assignments.map do |spe_assignment|
            [ spe_assignment.uuid, spe_assignment.algorithm_exercise_calculation_uuid ]
          end
          assignment_spe_where_query = <<~WHERE_SQL
            "assignment_spes"."id" IN (
              SELECT "assignment_spes"."id"
              FROM "assignment_spes"
              INNER JOIN (#{ValuesTable.new(assignment_spe_values)}) AS "values"
                ("assignment_uuid", "algorithm_exercise_calculation_uuid")
                ON "assignment_spes"."assignment_uuid" = "values"."assignment_uuid"::uuid
                AND "assignment_spes"."algorithm_exercise_calculation_uuid" =
                  "values"."algorithm_exercise_calculation_uuid"::uuid
            )
          WHERE_SQL
          AssignmentSpe.where(assignment_spe_where_query).ordered_delete_all
        end

        spe_student_uuids = spe_assignments.map(&:student_uuid)
        spe_assignment_types = spe_assignments.map(&:assignment_type)
        spe_assignment_uuids = spe_assignments.map(&:uuid)
        instructor_sequence_numbers_by_assignment_uuid = {}
        student_sequence_numbers_by_assignment_uuid = {}
        instructor_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        student_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        subquery = Assignment
          .where(uuid: spe_assignment_uuids)
          .select(
            :student_uuid,
            :assignment_type,
            :instructor_driven_sequence_number,
            :student_driven_sequence_number
          )
        Assignment
          .distinct
          .joins(
            <<~SQL
              INNER JOIN (#{subquery.to_sql}) "assignments_to_update"
                ON "assignments"."student_uuid" = "assignments_to_update"."student_uuid"
                  AND "assignments"."assignment_type" = "assignments_to_update"."assignment_type"
                  AND (
                    "assignments"."instructor_driven_sequence_number" <=
                      "assignments_to_update"."instructor_driven_sequence_number"
                      AND "assignments"."instructor_driven_sequence_number" >=
                        "assignments_to_update"."instructor_driven_sequence_number" - #{MAX_K_AGO}
                  ) OR (
                    "assignments"."student_driven_sequence_number" <=
                      "assignments_to_update"."student_driven_sequence_number"
                      AND "assignments"."student_driven_sequence_number" >=
                        "assignments_to_update"."student_driven_sequence_number" - #{MAX_K_AGO}
                  )
            SQL
          )
          .to_a_with_instructor_and_student_driven_sequence_numbers_cte(
            student_uuids: spe_student_uuids, assignment_types: spe_assignment_types
          )
          .each do |assignment|
          uuid = assignment.uuid
          student_uuid = assignment.student_uuid
          assignment_type = assignment.assignment_type
          ecosystem_uuid = assignment.ecosystem_uuid
          assigned_book_container_uuids = assignment.assigned_book_container_uuids
          instructor_driven_sequence_number = assignment.instructor_driven_sequence_number
          student_driven_sequence_number = assignment.student_driven_sequence_number

          instructor_sequence_numbers_by_assignment_uuid[uuid] = instructor_driven_sequence_number
          student_sequence_numbers_by_assignment_uuid[uuid] = student_driven_sequence_number

          instructor_histories[student_uuid][assignment_type][instructor_driven_sequence_number] = \
            [uuid, ecosystem_uuid, assigned_book_container_uuids]
          student_histories[student_uuid][assignment_type][student_driven_sequence_number] = \
            [uuid, ecosystem_uuid, assigned_book_container_uuids]
        end

        # Create a mapping of spaced practice book containers to each assignment's ecosystem
        bcm = BookContainerMapping.arel_table
        forward_mapping_values_array = spe_assignments.flat_map do |spe_assignment|
          uuid = spe_assignment.uuid
          student_uuid = spe_assignment.student_uuid
          assignment_type = spe_assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          to_ecosystem_uuid = spe_assignment.ecosystem_uuid

          instructor_spaced_assignments = K_AGOS_TO_LOAD.map do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
            instructor_history[instructor_spaced_sequence_number]
          end.compact
          student_spaced_assignments = K_AGOS_TO_LOAD.map do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
            student_history[student_spaced_sequence_number]
          end.compact

          (instructor_spaced_assignments + student_spaced_assignments)
            .uniq
            .map do |assignment_uuid, from_ecosystem_uuid, from_book_container_uuids|
            next if from_ecosystem_uuid == to_ecosystem_uuid

            [ to_ecosystem_uuid, from_ecosystem_uuid, from_book_container_uuids ]
          end.compact
        end
        ecosystems_map = Hash.new { |hash, key| hash[key] = {} }
        unless forward_mapping_values_array.empty?
          forward_mapping_join_query = <<~JOIN_SQL
            INNER JOIN (#{ValuesTable.new(forward_mapping_values_array)})
              AS "values" ("to_ecosystem_uuid", "from_ecosystem_uuid", "from_book_container_uuids")
              ON "book_container_mappings"."to_ecosystem_uuid" = "values"."to_ecosystem_uuid"::uuid
                AND "book_container_mappings"."from_ecosystem_uuid" =
                  "values"."from_ecosystem_uuid"::uuid
                AND "book_container_mappings"."from_book_container_uuid" =
                  ANY("values"."from_book_container_uuids"::uuid[])
          JOIN_SQL
          BookContainerMapping.joins(forward_mapping_join_query)
                              .pluck(
                                :to_ecosystem_uuid,
                                :from_book_container_uuid,
                                :to_book_container_uuid
                              ).each do |
                                to_ecosystem_uuid,
                                from_book_container_uuid,
                                to_book_container_uuid
                              |
            ecosystems_map[to_ecosystem_uuid][from_book_container_uuid] = to_book_container_uuid
          end
        end

        # Map all spaced book_container_uuids to the current ecosystem for each spaced assignment
        spaced_book_container_uuids = spe_assignments.flat_map do |spe_assignment|
          uuid = spe_assignment.uuid
          student_uuid = spe_assignment.student_uuid
          assignment_type = spe_assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          to_ecosystem_uuid = spe_assignment.ecosystem_uuid

          K_AGOS_TO_LOAD.flat_map do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
            spaced_uuid, instructor_from_ecosystem_uuid, instructor_spaced_book_container_uuids = \
              instructor_history[instructor_spaced_sequence_number]
            instructor_spaced_book_container_uuids ||= []

            if instructor_from_ecosystem_uuid == to_ecosystem_uuid
              instructor_spaced_book_container_uuids
            else
              instructor_spaced_book_container_uuids.map do |book_container_uuid|
                ecosystems_map[to_ecosystem_uuid][book_container_uuid]
              end
            end
          end + K_AGOS_TO_LOAD.flat_map do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
            spaced_uuid, student_from_ecosystem_uuid, student_spaced_book_container_uuids = \
              student_history[student_spaced_sequence_number]
            student_spaced_book_container_uuids ||= []

            if student_from_ecosystem_uuid == to_ecosystem_uuid
              student_spaced_book_container_uuids
            else
              student_spaced_book_container_uuids.map do |book_container_uuid|
                ecosystems_map[to_ecosystem_uuid][book_container_uuid]
              end
            end
          end
        end.uniq

        # Collect all relevant book container uuids for SPEs and PEs
        book_container_uuids = assignments.flat_map(&:assigned_book_container_uuids) +
                               spaced_book_container_uuids

        exercise_uuids_map = get_exercise_uuids_map book_container_uuids

        excluded_uuids_by_student_uuid = get_excluded_exercises_by_student_uuid(
          assignments, current_time: start_time
        )

        # Map book_container_uuids with exercises to the current assignment's ecosystem
        # Also store assignment_uuids for use in the SPE spy info
        # Each book_container_uuid can only appear in the history once (the most recent time)
        mapped_instructor_histories = Hash.new { |hash, key| hash[key] = {} }
        mapped_student_histories = Hash.new { |hash, key| hash[key] = {} }
        spe_assignments.each do |spe_assignment|
          uuid = spe_assignment.uuid
          assigned_book_container_uuids = spe_assignment.assigned_book_container_uuids

          # Add the current assignment as 0-ago
          mapped_instructor_histories[uuid][0] = {
            assignment_uuid: uuid,
            book_container_uuids: assigned_book_container_uuids
          }
          mapped_student_histories[uuid][0] = {
            assignment_uuid: uuid,
            book_container_uuids: assigned_book_container_uuids
          }

          student_uuid = spe_assignment.student_uuid
          assignment_type = spe_assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          to_ecosystem_uuid = spe_assignment.ecosystem_uuid

          assignment_type_exercise_uuids_map = exercise_uuids_map[assignment_type]
          excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          instructor_book_container_uuids = assigned_book_container_uuids.dup
          K_AGOS_TO_LOAD.each do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
            spaced_uuid, instructor_from_ecosystem_uuid, instructor_spaced_book_container_uuids = \
              instructor_history[instructor_spaced_sequence_number]
            instructor_spaced_book_container_uuids ||= []

            instructor_mapped_book_containers = (
              if instructor_from_ecosystem_uuid == to_ecosystem_uuid
                instructor_spaced_book_container_uuids
              else
                instructor_spaced_book_container_uuids.map do |book_container_uuid|
                  ecosystems_map[to_ecosystem_uuid][book_container_uuid]
                end
              end - instructor_book_container_uuids
            ).reject do |book_container_uuid|
              # Remove book containers that have no exercises after all exclusions
              # from the instructor history

              (
                assignment_type_exercise_uuids_map[book_container_uuid] - excluded_exercise_uuids
              ).empty?
            end

            instructor_book_container_uuids.concat instructor_mapped_book_containers

            mapped_instructor_histories[uuid][k_ago] = {
              assignment_uuid: spaced_uuid,
              book_container_uuids: instructor_mapped_book_containers
            }
          end

          student_book_container_uuids = assigned_book_container_uuids.dup
          K_AGOS_TO_LOAD.each do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
            spaced_uuid, student_from_ecosystem_uuid, student_spaced_book_container_uuids = \
              student_history[student_spaced_sequence_number]
            student_spaced_book_container_uuids ||= []

            student_mapped_book_containers = (
              if student_from_ecosystem_uuid == to_ecosystem_uuid
                student_spaced_book_container_uuids
              else
                student_spaced_book_container_uuids.map do |book_container_uuid|
                  ecosystems_map[to_ecosystem_uuid][book_container_uuid]
                end
              end - student_book_container_uuids
            ).reject do |book_container_uuid|
              # Remove book containers that have no exercises after all exclusions
              # from the student history

              (
                assignment_type_exercise_uuids_map[book_container_uuid] - excluded_exercise_uuids
              ).empty?
            end

            student_book_container_uuids.concat student_mapped_book_containers

            mapped_student_histories[uuid][k_ago] = {
              assignment_uuid: spaced_uuid,
              book_container_uuids: student_mapped_book_containers
            }
          end
        end

        # Personalized
        assignment_pe_requests = []
        assignment_pes = []
        pe_assignments.each do |assignment|
          algorithm_exercise_calculation_uuid = assignment.algorithm_exercise_calculation_uuid
          algorithm_exercise_calculation = algorithm_exercise_calculations_by_uuid
                                             .fetch(algorithm_exercise_calculation_uuid)
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]
          assignment_uuid = assignment.uuid

          pe_request = build_pe_request(
            algorithm_exercise_calculation: algorithm_exercise_calculation,
            assignment: assignment,
            exercise_uuids_map: exercise_uuids_map,
            excluded_exercise_uuids: student_excluded_exercise_uuids
          )
          assignment_pe_requests << pe_request

          exercise_uuids = pe_request[:exercise_uuids]
          pes = exercise_uuids.map do |exercise_uuid|
            AssignmentPe.new(
              uuid: SecureRandom.uuid,
              algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
              assignment_uuid: assignment_uuid,
              exercise_uuid: exercise_uuid
            )
          end
          assignment_pes.concat pes
        end

        # Send the AssignmentPes to the api server and record them
        OpenStax::Biglearn::Api.update_assignment_pes(assignment_pe_requests) \
          if assignment_pe_requests.any?

        # No sort needed because no conflict clause
        AssignmentPe.import assignment_pes, validate: false

        excluded_pe_uuids_by_assignment_uuid = Hash.new { |hash, key| hash[key] = [] }
        AssignmentPe
          .where(assignment_uuid: spe_assignment_uuids)
          .where.not(exercise_uuid: nil)
          .pluck(:assignment_uuid, :exercise_uuid)
          .each do |assignment_uuid, exercise_uuid|
          excluded_pe_uuids_by_assignment_uuid[assignment_uuid] << exercise_uuid
        end

        # Spaced Practice
        assignment_spe_requests = []
        assignment_spes = []
        spe_assignments.each do |assignment|
          assignment_uuid = assignment.uuid
          assignment_type = assignment.assignment_type
          student_uuid = assignment.student_uuid
          algorithm_exercise_calculation_uuid = assignment.algorithm_exercise_calculation_uuid
          algorithm_exercise_calculation = algorithm_exercise_calculations_by_uuid
                                             .fetch(algorithm_exercise_calculation_uuid)
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          assigned_book_container_uuids = assignment.assigned_book_container_uuids

          mapped_instructor_history = mapped_instructor_histories[assignment_uuid]
          mapped_student_history = mapped_student_histories[assignment_uuid]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(
            assignment_uuid
          )
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(
            assignment_uuid
          )

          excluded_exercise_uuids = student_excluded_exercise_uuids +
                                    excluded_pe_uuids_by_assignment_uuid[assignment_uuid]

          # Instructor-driven
          instructor_driven_spe_request = build_spe_request(
            algorithm_exercise_calculation: algorithm_exercise_calculation,
            assignment: assignment,
            assignment_sequence_number: instructor_sequence_number,
            history_type: :instructor_driven,
            assignment_history: mapped_instructor_history,
            exercise_uuids_map: exercise_uuids_map,
            excluded_exercise_uuids: excluded_exercise_uuids
          )
          assignment_spe_requests << instructor_driven_spe_request

          instructor_driven_exercise_uuids = instructor_driven_spe_request[:exercise_uuids]
          instructor_driven_spes = instructor_driven_exercise_uuids.map do |exercise_uuid|
            AssignmentSpe.new(
              uuid: SecureRandom.uuid,
              algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
              assignment_uuid: assignment_uuid,
              history_type: :instructor_driven,
              exercise_uuid: exercise_uuid
            )
          end
          assignment_spes.concat instructor_driven_spes

          # Student-driven
          student_driven_spe_request = build_spe_request(
            algorithm_exercise_calculation: algorithm_exercise_calculation,
            assignment: assignment,
            assignment_sequence_number: student_sequence_number,
            history_type: :student_driven,
            assignment_history: mapped_student_history,
            exercise_uuids_map: exercise_uuids_map,
            excluded_exercise_uuids: excluded_exercise_uuids
          )
          assignment_spe_requests << student_driven_spe_request

          student_driven_exercise_uuids = student_driven_spe_request[:exercise_uuids]
          student_driven_spes = student_driven_exercise_uuids.map do |exercise_uuid|
            AssignmentSpe.new(
              uuid: SecureRandom.uuid,
              algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
              assignment_uuid: assignment_uuid,
              history_type: :student_driven,
              exercise_uuid: exercise_uuid
            )
          end
          assignment_spes.concat student_driven_spes
        end

        # Send the AssignmentSpes to the api server and record them
        OpenStax::Biglearn::Api.update_assignment_spes(assignment_spe_requests) \
          if assignment_spe_requests.any?

        # No sort needed because no conflict clause
        AssignmentSpe.import assignment_spes, validate: false

        # Mark the AlgorithmExerciseCalculations as uploaded (even the superseded ones)
        all_assignments.group_by(
          &:algorithm_exercise_calculation_uuid
        ).each do |calc_uuid, assignments|
          algorithm_exercise_calculation = algorithm_exercise_calculations_by_uuid[calc_uuid]
          algorithm_exercise_calculation.pending_assignment_uuids -= assignments.map(&:uuid)
        end

        # Mark AlgorithmExerciseCalculations with conflicting AssignmentSpes for recalculation
        unless assignment_pes.empty?
          assignment_pe_uuids = assignment_pes.map(&:uuid)

          AlgorithmExerciseCalculation
            .select(aec[Arel.star], aspe[:assignment_uuid])
            .joins(assignment_spes: :conflicting_assignment_pes)
            .where(assignment_spes: { conflicting_assignment_pes: { uuid: assignment_pe_uuids } })
            .group_by(&:uuid)
            .each do |uuid, algorithm_exercise_calculations|
            algorithm_exercise_calculations_by_uuid[uuid] ||= algorithm_exercise_calculations.first
            algorithm_exercise_calculations_by_uuid[uuid].pending_assignment_uuids = (
              algorithm_exercise_calculations_by_uuid[uuid].pending_assignment_uuids +
              algorithm_exercise_calculations.map(&:assignment_uuid)
            ).uniq
          end
        end

        # No sort needed because already locked above
        AlgorithmExerciseCalculation.import(
          algorithm_exercise_calculations_by_uuid.values,
          validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ], columns: [ :pending_assignment_uuids ]
          }
        )

        algorithm_exercise_calculations_size
      end

      # If we got less calculations than the batch size, then this is the last batch
      total_algorithm_exercise_calculations += num_algorithm_exercise_calculations
      break if num_algorithm_exercise_calculations < BATCH_SIZE
    end

    log(:debug) do
      "#{total_algorithm_exercise_calculations} algorithm exercise calculations(s) processed in #{
      Time.current - start_time} second(s)"
    end
  end
end

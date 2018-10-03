class Services::UploadAssignmentExercises::Service < Services::ApplicationService
  BATCH_SIZE = 10

  DEFAULT_NUM_PES_PER_BOOK_CONTAINER = 3
  DEFAULT_NUM_SPES_PER_K_AGO = 1

  K_AGOS_TO_LOAD = [ 1, 2, 3, 4, 5 ]
  NON_RANDOM_K_AGOS = [ 1, 3, 5 ]
  MAX_K_AGO = K_AGOS_TO_LOAD.max

  MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO = 5

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
        algorithm_exercise_calculations_by_uuid = AlgorithmExerciseCalculation
          .joins(:exercise_calculation)
          .where(
            Assignment.need_pes_or_spes.where(
              aa[:student_uuid].eq(ec[:student_uuid]).and(
                aa[:ecosystem_uuid].eq(ec[:ecosystem_uuid])
              )
            )
            .where.not(
              <<-NOT_SQL.strip_heredoc
                "algorithm_exercise_calculations"."is_uploaded_for_assignment_uuids" @>
                ARRAY["assignments"."uuid"]::varchar[]
              NOT_SQL
            ).exists
          )
          .lock('FOR NO KEY UPDATE OF "algorithm_exercise_calculations" SKIP LOCKED')
          .limit(BATCH_SIZE)
          .index_by(&:uuid)
        algorithm_exercise_calculation_uuids = algorithm_exercise_calculations_by_uuid.keys

        assignments = Assignment
          .need_pes_or_spes
          .select([ aa[Arel.star], aec[:uuid].as('algorithm_exercise_calculation_uuid') ])
          .joins(exercise_calculation: :algorithm_exercise_calculations)
          .where(algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids })
          .where.not(
            <<-NOT_SQL.strip_heredoc
              "algorithm_exercise_calculations"."is_uploaded_for_assignment_uuids" @>
              ARRAY["assignments"."uuid"]::varchar[]
            NOT_SQL
          )

        # Delete relevant AssignmentPe and AssignmentSpes, since we are about to reupload them
        pe_assignments = assignments.select(&:needs_pes?)
        unless pe_assignments.empty?
          assignment_pe_values = pe_assignments.map do |pe_assignment|
            [ pe_assignment.uuid, pe_assignment.algorithm_exercise_calculation_uuid ]
          end
          assignment_pe_where_query = <<-WHERE_SQL.strip_heredoc
            "assignment_pes"."id" IN (
              SELECT "assignment_pes"."id"
              FROM "assignment_pes"
              INNER JOIN (#{ValuesTable.new(assignment_pe_values)}) AS "values"
                ("assignment_uuid", "algorithm_exercise_calculation_uuid")
                ON "assignment_pes"."assignment_uuid" = "values"."assignment_uuid"
                AND "assignment_pes"."algorithm_exercise_calculation_uuid" =
                  "values"."algorithm_exercise_calculation_uuid"
            )
          WHERE_SQL
          AssignmentPe.where(assignment_pe_where_query).ordered_delete_all
        end
        spe_assignments = assignments.select(&:needs_spes?)
        unless spe_assignments.empty?
          assignment_spe_values = spe_assignments.map do |spe_assignment|
            [ spe_assignment.uuid, spe_assignment.algorithm_exercise_calculation_uuid ]
          end
          assignment_spe_where_query = <<-WHERE_SQL.strip_heredoc
            "assignment_spes"."id" IN (
              SELECT "assignment_spes"."id"
              FROM "assignment_spes"
              INNER JOIN (#{ValuesTable.new(assignment_spe_values)}) AS "values"
                ("assignment_uuid", "algorithm_exercise_calculation_uuid")
                ON "assignment_spes"."assignment_uuid" = "values"."assignment_uuid"
                AND "assignment_spes"."algorithm_exercise_calculation_uuid" =
                  "values"."algorithm_exercise_calculation_uuid"
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
            <<-SQL.strip_heredoc
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
          forward_mapping_join_query = <<-JOIN_SQL.strip_heredoc
            INNER JOIN (#{ValuesTable.new(forward_mapping_values_array)})
              AS "values" ("to_ecosystem_uuid", "from_ecosystem_uuid", "from_book_container_uuids")
              ON "book_container_mappings"."to_ecosystem_uuid" = "values"."to_ecosystem_uuid"
                AND "book_container_mappings"."from_ecosystem_uuid" = "values"."from_ecosystem_uuid"
                AND "book_container_mappings"."from_book_container_uuid" =
                  ANY("values"."from_book_container_uuids")
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

        # Get exercises for all relevant book_container_uuids
        @exercise_uuids_map = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        ExercisePool.where(book_container_uuid: book_container_uuids).pluck(
          :book_container_uuid,
          :use_for_personalized_for_assignment_types,
          :exercise_uuids
        ).each do |book_container_uuid, assignment_types, exercise_uuids|
          assignment_types.each do |assignment_type|
            @exercise_uuids_map[assignment_type][book_container_uuid].concat exercise_uuids
          end
        end

        # Get exercise exclusions for each course
        course_uuids = assignments.map(&:course_uuid)
        course_exclusions_by_course_uuid = Course.where(uuid: course_uuids).pluck(
          :uuid,
          :global_excluded_exercise_uuids,
          :course_excluded_exercise_uuids,
          :global_excluded_exercise_group_uuids,
          :course_excluded_exercise_group_uuids
        ).index_by(&:first)

        # Get assignments that should have hidden feedback for each student
        student_uuids = assignments.map(&:student_uuid)
        no_feedback_yet_assignments = Assignment
                                        .where(student_uuid: student_uuids)
                                        .where(aa[:feedback_at].gt(start_time))
                                        .pluck(:student_uuid, :assigned_exercise_uuids)

        # Convert excluded exercise uuids to group uuids
        assigned_exercise_uuids = no_feedback_yet_assignments.flat_map(&:second)
        assigned_exercise_group_uuid_by_uuid = Exercise.where(uuid: assigned_exercise_uuids)
                                                       .pluck(:uuid, :group_uuid)
                                                       .to_h

        # Convert exclusion group uuids to uuids
        excluded_exercise_group_uuids = course_exclusions_by_course_uuid.values.flat_map(&:fourth) +
                                        course_exclusions_by_course_uuid.values.flat_map(&:fifth) +
                                        assigned_exercise_group_uuid_by_uuid.values
        excluded_exercise_uuids_by_group_uuid = Hash.new { |hash, key| hash[key] = [] }
        Exercise.where(group_uuid: excluded_exercise_group_uuids)
                .pluck(:group_uuid, :uuid)
                .each do |group_uuid, uuid|
          excluded_exercise_uuids_by_group_uuid[group_uuid] << uuid
        end

        # Create a map of excluded exercise uuids for each student
        excluded_uuids_by_student_uuid = Hash.new { |hash, key| hash[key] = [] }

        # Add the course exclusions to the map above
        assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
          course_exclusions = course_exclusions_by_course_uuid[course_uuid]
          next if course_exclusions.nil?

          group_uuids = course_exclusions.fourth + course_exclusions.fifth
          converted_excluded_exercise_uuids =
            excluded_exercise_uuids_by_group_uuid.values_at(*group_uuids).flatten
          course_excluded_uuids = course_exclusions.second +
                                  course_exclusions.third +
                                  converted_excluded_exercise_uuids

          assignments.each do |assignment|
            excluded_uuids_by_student_uuid[assignment.student_uuid].concat course_excluded_uuids
          end
        end

        # Add the exclusions from no_feedback_yet_assignments to the map above
        no_feedback_yet_assignments.each do |student_uuid, assigned_exercise_uuids|
          excluded_group_uuids =
            assigned_exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
          excluded_exercise_uuids =
            excluded_exercise_uuids_by_group_uuid.values_at(*excluded_group_uuids).flatten
          excluded_uuids_by_student_uuid[student_uuid].concat excluded_exercise_uuids
        end

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

          assignment_type_exercise_uuids_map = @exercise_uuids_map[assignment_type]
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
          algorithm_name = algorithm_exercise_calculation.algorithm_name
          prioritized_exercise_uuids = algorithm_exercise_calculation.exercise_uuids
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]
          assignment_uuid = assignment.uuid

          pe_request = build_pe_request(
            assignment: assignment,
            algorithm_name: algorithm_name,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
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
          algorithm_name = algorithm_exercise_calculation.algorithm_name
          prioritized_exercise_uuids = algorithm_exercise_calculation.exercise_uuids
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
            assignment: assignment,
            assignment_sequence_number: instructor_sequence_number,
            history_type: :instructor_driven,
            assignment_history: mapped_instructor_history,
            algorithm_name: algorithm_name,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
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
            assignment: assignment,
            assignment_sequence_number: student_sequence_number,
            history_type: :student_driven,
            assignment_history: mapped_student_history,
            algorithm_name: algorithm_name,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
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

        # Remove SPEs for any assignments that are using the PEs above (PEs have priority over SPEs)
        unless assignment_pes.empty?
          assignment_pe_uuids = assignment_pes.map(&:uuid)

          AssignmentSpe.joins(:conflicting_assignment_pes)
                       .where(assignment_pes: { uuid: assignment_pe_uuids })
                       .ordered_delete_all
        end

        # Mark the AlgorithmExerciseCalculations as uploaded
        assignments.each do |assignment|
          algorithm_exercise_calculation =
            algorithm_exercise_calculations_by_uuid[assignment.algorithm_exercise_calculation_uuid]
          algorithm_exercise_calculation.is_uploaded_for_assignment_uuids =
            algorithm_exercise_calculation.is_uploaded_for_assignment_uuids + [ assignment.uuid ]
        end
        algorithm_exercise_calculations = algorithm_exercise_calculations_by_uuid.values
        # No sort needed because already locked above
        AlgorithmExerciseCalculation.import(
          algorithm_exercise_calculations,
          validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ], columns: [ :is_uploaded_for_assignment_uuids ]
          }
        )

        algorithm_exercise_calculations.size
      end

      # If we got less records than both batch sizes, then this is the last batch
      total_algorithm_exercise_calculations += num_algorithm_exercise_calculations
      break if num_algorithm_exercise_calculations < BATCH_SIZE
    end

    log(:debug) do
      "#{total_algorithm_exercise_calculations} algorithm exercise calculations(s) processed in #{
      Time.current - start_time} second(s)"
    end
  end

  protected

  def get_k_ago_map(assignment, include_random_ago = false)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    num_spes = assignment.goal_num_tutor_assigned_spes

    case num_spes
    when Integer
      # Tutor decides
      return [] if num_spes == 0

      # Subtract 1 for random-ago/personalized
      num_spes -= 1
      num_spes_per_k_ago, remainder = num_spes.divmod NON_RANDOM_K_AGOS.size

      [].tap do |k_ago_map|
        NON_RANDOM_K_AGOS.each_with_index do |k_ago, index|
          num_k_ago_spes = index < remainder ? num_spes_per_k_ago + 1 : num_spes_per_k_ago

          k_ago_map << [k_ago, num_k_ago_spes] if num_k_ago_spes > 0
        end

        k_ago_map << [(include_random_ago ? nil : 0), 1]
      end
    when NilClass
      # Biglearn decides
      NON_RANDOM_K_AGOS.map do |k_ago|
        [k_ago, DEFAULT_NUM_SPES_PER_K_AGO]
      end.compact.tap do |k_ago_map|
        k_ago_map << [(include_random_ago ? nil : 0), 1]
      end
    else
      raise ArgumentError, "Invalid assignment num_spes: #{num_spes.inspect}", caller
    end
  end

  def choose_exercise_uuids(
    assignment:,
    book_container_uuids:,
    prioritized_exercise_uuids:,
    excluded_exercise_uuids:,
    exercise_count:
  )
    book_container_uuids = [book_container_uuids].flatten

    # Get exercises in relevant book containers for the relevant assignment type
    book_container_exercise_uuids =
      @exercise_uuids_map[assignment.assignment_type].values_at(*book_container_uuids).flatten

    # Remove duplicates (same assignment), assigned exercises and exclusions
    allowed_exercise_uuids = book_container_exercise_uuids -
                             assignment.assigned_exercise_uuids -
                             excluded_exercise_uuids

    (prioritized_exercise_uuids & allowed_exercise_uuids).first(exercise_count)
  end

  def build_pe_request(assignment:,
                       algorithm_name:,
                       prioritized_exercise_uuids:,
                       excluded_exercise_uuids:)
    assignment_type = assignment.assignment_type
    assignment_type_exercise_uuids_map = @exercise_uuids_map[assignment.assignment_type]
    assignment_excluded_uuids = excluded_exercise_uuids
    # Ignore book containers with no dynamic exercises
    book_container_uuids = assignment.assigned_book_container_uuids
                                     .uniq
                                     .reject do |book_container_uuid|
      ( assignment_type_exercise_uuids_map[book_container_uuid] - assignment_excluded_uuids ).empty?
    end.shuffle

    unless book_container_uuids.empty?
      num_pes_per_book_container, remainder = assignment.goal_num_tutor_assigned_pes.nil? ?
        [DEFAULT_NUM_PES_PER_BOOK_CONTAINER, 0] :
        assignment.goal_num_tutor_assigned_pes.divmod(book_container_uuids.size)
    end

    chosen_pe_uuids = book_container_uuids.flat_map do |book_container_uuid|
      book_container_num_pes = remainder > 0 ?
        num_pes_per_book_container + 1 : num_pes_per_book_container
      next [] if book_container_num_pes == 0

      choose_exercise_uuids(
        assignment: assignment,
        book_container_uuids: book_container_uuid,
        prioritized_exercise_uuids: prioritized_exercise_uuids,
        excluded_exercise_uuids: assignment_excluded_uuids,
        exercise_count: book_container_num_pes
      ).tap do |chosen_pe_uuids|
        num_chosen_pes = chosen_pe_uuids.size
        remainder += num_pes_per_book_container - num_chosen_pes
        assignment_excluded_uuids += chosen_pe_uuids
      end
    end

    {
      assignment_uuid: assignment.uuid,
      exercise_uuids: chosen_pe_uuids,
      algorithm_name: algorithm_name,
      spy_info: {
        assignment_type: assignment_type,
        exercise_algorithm_name: algorithm_name
      }
    }
  end

  def build_spe_request(assignment:,
                        assignment_sequence_number:,
                        history_type:,
                        assignment_history:,
                        algorithm_name:,
                        prioritized_exercise_uuids:,
                        excluded_exercise_uuids:)
    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type

    include_random_ago = history_type == :student_driven &&
                         assignment_sequence_number >= MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO
    k_ago_map = get_k_ago_map(assignment, include_random_ago)

    assignment_excluded_uuids = excluded_exercise_uuids

    forbidden_random_k_agos = k_ago_map.map(&:first).compact
    allowed_random_k_agos = K_AGOS_TO_LOAD - forbidden_random_k_agos
    num_remaining_exercises = 0
    exercises_spy_info = {}
    chosen_spe_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
      num_remaining_exercises += num_exercises

      k_agos = k_ago.nil? ? allowed_random_k_agos : [ k_ago ]
      spaced_assignments = assignment_history.values_at(*k_agos).flatten.compact
      book_container_uuids = spaced_assignments.flat_map { |hash| hash[:book_container_uuids] }
                                               .uniq
                                               .shuffle
      num_book_containers = book_container_uuids.size

      next [] if num_book_containers == 0

      # k-ago assignment exists
      num_spes_per_book_container, remainder = num_remaining_exercises.divmod(num_book_containers)

      book_container_uuids.flat_map do |book_container_uuid|
        book_container_num_spes = remainder > 0 ?
          num_spes_per_book_container + 1 : num_spes_per_book_container
        next [] if book_container_num_spes == 0

        choose_exercise_uuids(
          assignment: assignment,
          book_container_uuids: book_container_uuid,
          prioritized_exercise_uuids: prioritized_exercise_uuids,
          excluded_exercise_uuids: assignment_excluded_uuids,
          exercise_count: book_container_num_spes
        ).tap do |chosen_spe_uuids|
          num_chosen_spes = chosen_spe_uuids.size
          num_remaining_exercises -= num_chosen_spes
          remainder += num_spes_per_book_container - num_chosen_spes
          assignment_excluded_uuids += chosen_spe_uuids

          # SPE spy info
          chosen_k_ago = k_ago.nil? ? assignment_history.find do |k_ago, history_entry|
            history_entry[:book_container_uuids].include? book_container_uuid
          end.first : k_ago
          chosen_spe_uuids.each do |chosen_spe_uuid|
            exercises_spy_info[chosen_spe_uuid] = { k_ago: chosen_k_ago, is_random_ago: k_ago.nil? }
          end
        end
      end
    end

    # If not enough spaced practice exercises, fill up the rest with personalized ones
    chosen_pe_uuids = choose_exercise_uuids(
      assignment: assignment,
      book_container_uuids: assignment.assigned_book_container_uuids,
      prioritized_exercise_uuids: prioritized_exercise_uuids,
      excluded_exercise_uuids: assignment_excluded_uuids,
      exercise_count: num_remaining_exercises
    )

    # PE as SPE spy info
    chosen_pe_uuids.each do |chosen_pe_uuid|
      exercises_spy_info[chosen_pe_uuid] = { k_ago: 0, is_random_ago: false }
    end

    {
      assignment_uuid: assignment_uuid,
      exercise_uuids: chosen_spe_uuids + chosen_pe_uuids,
      algorithm_name: "#{history_type}_#{algorithm_name}",
      spy_info: {
        assignment_type: assignment_type,
        exercise_algorithm_name: algorithm_name,
        history_type: history_type,
        assignment_history: assignment_history,
        exercises: exercises_spy_info
      }
    }
  end
end

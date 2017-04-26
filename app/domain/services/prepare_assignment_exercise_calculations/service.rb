class Services::PrepareAssignmentExerciseCalculations::Service
  BATCH_SIZE = 1000

  DEFAULT_NUM_PES_PER_BOOK_CONTAINER = 3
  DEFAULT_NUM_SPES_PER_K_AGO_BOOK_CONTAINER = 1

  MIN_RANDOM_AGO = 1
  MAX_RANDOM_AGO = 5
  MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO = 5

  # NOTE: We don't support partial PE/SPE assignments yet, we do all of them in one go
  # If partial assignments are needed, we can look at AssignedExercise records
  # to figure out how many PEs and SPEs we have, but will potentially need to add more info
  # like book_container_uuid and k_ago to these records
  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareAssignmentExerciseCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    aa = Assignment.arel_table
    query = aa[:spes_are_assigned].eq(false).and(
              aa[:goal_num_tutor_assigned_spes].eq(nil).or(aa[:goal_num_tutor_assigned_spes].gt(0))
            ).or(
              aa[:pes_are_assigned].eq(false).and(
                aa[:goal_num_tutor_assigned_pes].eq(nil).or(aa[:goal_num_tutor_assigned_pes].gt(0))
              )
            )

    total_assignments = 0
    loop do
      num_assignments = Assignment.transaction do
        assignments = Assignment.with_instructor_and_student_driven_sequence_numbers
                                .where(query)
                                .take(BATCH_SIZE)

        # Build assignment histories so we can find SPE book_container_uuids
        student_random_ago_by_assignment_uuid = {}
        history_queries = assignments.map do |assignment|
          instructor_driven_sequence_number = assignment.instructor_driven_sequence_number
          student_driven_sequence_number = assignment.student_driven_sequence_number
          instructor_k_agos = get_k_agos
          instructor_sequence_number_queries = instructor_k_agos.map do |k_ago|
            aa[:instructor_driven_sequence_number].eq(instructor_driven_sequence_number - k_ago)
          end

          # Find the max allowed k for random-ago
          student_random_ago = nil
          if student_driven_sequence_number >= MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO
            student_max_random_ago = [student_driven_sequence_number - 1, MAX_RANDOM_AGO].min
            k_agos_without_random_ago = get_k_agos
            student_random_ago = \
              ((1..student_max_random_ago).to_a - k_agos_without_random_ago).sample
          end

          student_random_ago_by_assignment_uuid[assignment.uuid] = student_random_ago
          student_sequence_number_queries = get_k_agos(student_random_ago).map do |k_ago|
            aa[:student_driven_sequence_number].eq(student_driven_sequence_number - k_ago)
          end

          sequence_number_query = (
            instructor_sequence_number_queries + student_sequence_number_queries
          ).reduce(:or)

          aa[:student_uuid].eq(assignment.student_uuid).and(
            aa[:assignment_type].eq(assignment.assignment_type).and(sequence_number_query)
          ) unless sequence_number_query.nil?
        end.compact.reduce(:or)
        instructor_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        student_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        Assignment.with_instructor_and_student_driven_sequence_numbers
                  .where(history_queries)
                  .pluck(
                    :student_uuid,
                    :assignment_type,
                    :instructor_driven_sequence_number,
                    :student_driven_sequence_number,
                    :ecosystem_uuid,
                    :assigned_book_container_uuids
                  ).each do |
                    student_uuid,
                    assignment_type,
                    instructor_driven_sequence_number,
                    student_driven_sequence_number,
                    ecosystem_uuid,
                    assigned_book_container_uuids
                  |
          instructor_histories[student_uuid][assignment_type][instructor_driven_sequence_number] = \
            [ecosystem_uuid, assigned_book_container_uuids]
          student_histories[student_uuid][assignment_type][student_driven_sequence_number] = \
            [ecosystem_uuid, assigned_book_container_uuids]
        end unless history_queries.nil?

        # Create a mapping of spaced practice book containers to each assignment's ecosystem
        bcm = BookContainerMapping.arel_table
        mapping_queries = assignments.map do |assignment|
          student_uuid = assignment.student_uuid
          assignment_type = assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_driven_sequence_number = assignment.instructor_driven_sequence_number
          student_driven_sequence_number = assignment.student_driven_sequence_number
          to_ecosystem_uuid = assignment.ecosystem_uuid

          instructor_spaced_assignments = get_k_agos.map do |k_ago|
            instructor_spaced_sequence_number = instructor_driven_sequence_number - k_ago
            instructor_history[instructor_spaced_sequence_number]
          end.compact
          student_random_ago = student_random_ago_by_assignment_uuid[assignment.uuid]
          student_spaced_assignments = get_k_agos(student_random_ago).map do |k_ago|
            student_spaced_sequence_number = student_driven_sequence_number - k_ago
            student_history[student_spaced_sequence_number]
          end.compact

          from_queries = (instructor_spaced_assignments + student_spaced_assignments)
                           .map do |from_ecosystem_uuid, from_book_container_uuids|
            next if from_ecosystem_uuid == to_ecosystem_uuid

            bcm[:from_ecosystem_uuid].eq(from_ecosystem_uuid).and(
              bcm[:from_book_container_uuid].in(from_book_container_uuids)
            )
          end.compact.reduce(:or)

          bcm[:to_ecosystem_uuid].eq(to_ecosystem_uuid).and(from_queries) unless from_queries.nil?
        end.compact.reduce(:or)
        ecosystems_map = Hash.new { |hash, key| hash[key] = {} }
        BookContainerMapping.where(mapping_queries)
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
        end unless mapping_queries.nil?

        # Map all spaced book_container_uuids to the current ecosystem for each assignment
        instructor_book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        student_book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        assignments.each do |assignment|
          assignment_uuid = assignment.uuid
          student_uuid = assignment.student_uuid
          assignment_type = assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_driven_sequence_number = assignment.instructor_driven_sequence_number
          student_driven_sequence_number = assignment.student_driven_sequence_number
          to_ecosystem_uuid = assignment.ecosystem_uuid

          get_k_agos.each do |k_ago|
            instructor_spaced_sequence_number = instructor_driven_sequence_number - k_ago
            instructor_from_ecosystem_uuid, instructor_spaced_book_container_uuids = \
              instructor_history[instructor_spaced_sequence_number]
            instructor_spaced_book_container_uuids ||= []

            instructor_mapped_book_containers = \
            if instructor_from_ecosystem_uuid == to_ecosystem_uuid
              instructor_spaced_book_container_uuids
            else
              instructor_spaced_book_container_uuids.map do |book_container_uuid|
                ecosystems_map[to_ecosystem_uuid][book_container_uuid]
              end
            end

            instructor_book_container_uuids_map[assignment_uuid][k_ago] = \
              instructor_mapped_book_containers
          end
          student_random_ago = student_random_ago_by_assignment_uuid[assignment_uuid]
          get_k_agos(student_random_ago).each do |k_ago|
            student_spaced_sequence_number = student_driven_sequence_number - k_ago
            student_from_ecosystem_uuid, student_spaced_book_container_uuids = \
              student_history[student_spaced_sequence_number]
            student_spaced_book_container_uuids ||= []

            student_mapped_book_containers = if student_from_ecosystem_uuid == to_ecosystem_uuid
              student_spaced_book_container_uuids
            else
              student_spaced_book_container_uuids.map do |book_container_uuid|
                ecosystems_map[to_ecosystem_uuid][book_container_uuid]
              end
            end

            student_book_container_uuids_map[assignment_uuid][k_ago] = \
              student_mapped_book_containers
          end
        end

        # Collect all relevant book container uuids for SPEs and PEs
        book_container_uuids = instructor_book_container_uuids_map.values.map(&:values).flatten +
                               student_book_container_uuids_map.values.map(&:values).flatten +
                               assignments.flat_map(&:assigned_book_container_uuids)

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
            @exercise_uuids_map[book_container_uuid][assignment_type].concat exercise_uuids
          end
        end

        # Get exercise exclusions for each course
        course_uuids = assignments.map(&:course_uuid)
        exclusions = Course.where(uuid: course_uuids).pluck(
          :uuid,
          :global_excluded_exercise_uuids,
          :course_excluded_exercise_uuids,
          :global_excluded_exercise_group_uuids,
          :course_excluded_exercise_group_uuids
        )

        excluded_exercise_group_uuids = exclusions.flat_map(&:fourth) + exclusions.flat_map(&:fifth)
        excluded_exercise_uuids_by_group_uuid = Hash.new { |hash, key| hash[key] = [] }
        Exercise.where(group_uuid: excluded_exercise_group_uuids)
                .pluck(:group_uuid, :uuid)
                .each do |group_uuid, uuid|
          excluded_exercise_uuids_by_group_uuid[group_uuid] << uuid
        end

        excluded_uuids_by_course_uuid = Hash.new { |hash, key| hash[key] = [] }
        exclusions.each do |
          uuid,
          global_excluded_exercise_uuids,
          course_excluded_exercise_uuids,
          global_excluded_exercise_group_uuids,
          course_excluded_exercise_group_uuids
        |
          group_uuids = global_excluded_exercise_group_uuids + course_excluded_exercise_group_uuids
          converted_excluded_exercise_uuids = group_uuids.flat_map do |group_uuid|
            excluded_exercise_uuids_by_group_uuid[group_uuid]
          end

          excluded_uuids_by_course_uuid[uuid].concat(
            global_excluded_exercise_uuids +
            course_excluded_exercise_uuids +
            converted_excluded_exercise_uuids
          )
        end

        # Get exercises that have already been assigned to each student
        student_uuids = assignments.map(&:student_uuid)
        student_assignments = Assignment
                                .where(student_uuid: student_uuids)
                                .pluck(:uuid, :student_uuid, :due_at, :assigned_exercise_uuids)
        student_assignment_uuids = student_assignments.map(&:first)
        times_assigned_by_student_uuid_and_exercise_uuid = Hash.new do |hash, key|
          hash[key] = Hash.new(0)
        end
        assigned_and_not_due_exercise_uuids_by_student_uuid = Hash.new do |hash, key|
          hash[key] = []
        end
        student_assignments.each do |uuid, student_uuid, due_at, assigned_exercise_uuids|
          assigned_exercise_uuids.each do |exercise_uuid|
            times_assigned_by_student_uuid_and_exercise_uuid[student_uuid][exercise_uuid] += 1
          end

          assigned_and_not_due_exercise_uuids_by_student_uuid[student_uuid].concat(
            assigned_exercise_uuids
          ) if due_at.present? && due_at > start_time
        end

        # Convert relevant exercise uuids to group uuids
        relevant_exercise_uuids = ( @exercise_uuids_map.values.map(&:values) +
                                    student_assignments.map(&:fourth) ).flatten
        @exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                               .pluck(:uuid, :group_uuid)
                                               .to_h

        # Convert the maps above to use exercise_group_uuids
        @times_assigned_by_student_uuid_and_exercise_group_uuid = Hash.new do |hash, key|
          hash[key] = Hash.new(0)
        end
        @assigned_and_not_due_exercise_group_uuids_by_student_uuid = Hash.new do |hash, key|
          hash[key] = []
        end
        times_assigned_by_student_uuid_and_exercise_uuid
          .each do |student_uuid, times_assigned_by_exercise_uuid|
          times_assigned_by_exercise_uuid.each do |exercise_uuid, times_assigned|
            group_uuid = @exercise_group_uuid_by_uuid[exercise_uuid]
            @times_assigned_by_student_uuid_and_exercise_group_uuid[student_uuid][group_uuid] +=
              times_assigned
          end
        end
        assigned_and_not_due_exercise_uuids_by_student_uuid
          .each do |student_uuid, assigned_and_not_due_exercise_uuids|
          @assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid] =
            @exercise_group_uuid_by_uuid.values_at(*assigned_and_not_due_exercise_uuids).unique
        end

        # Create SPE and PE calculations to be sent to the algorithms
        assignment_pe_calculations = []
        assignment_spe_calculations = []
        assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]

          assignments.each do |assignment|
            assignment_uuid = assignment.uuid
            assignment_type = assignment.assignment_type
            student_uuid = assignment.student_uuid

            assigned_book_container_uuids = assignment.assigned_book_container_uuids

            assignment_instructor_book_container_uuids_map = \
              instructor_book_container_uuids_map[assignment_uuid]
            assignment_student_book_container_uuids_map = \
              student_book_container_uuids_map[assignment_uuid]

            instructor_history = instructor_histories[student_uuid][assignment_type]
            student_history = student_histories[student_uuid][assignment_type]

            # Personalized
            assignment_pe_calculations.concat new_pe_calculations(
              assignment: assignment, course_excluded_uuids: course_excluded_uuids
            )

            assignment.pes_are_assigned = true

            # Spaced Practice

            # Instructor-driven
            assignment_spe_calculations.concat new_spe_calculations(
              assignment: assignment,
              assignment_sequence_number: assignment.instructor_driven_sequence_number,
              history: instructor_history,
              history_type: :instructor_driven,
              assignment_book_container_uuids_map: assignment_instructor_book_container_uuids_map,
              course_excluded_uuids: course_excluded_uuids
            )

            # Student-driven
            student_random_ago = student_random_ago_by_assignment_uuid[assignment_uuid]
            assignment_spe_calculations.concat new_spe_calculations(
              assignment: assignment,
              assignment_sequence_number: assignment.student_driven_sequence_number,
              history: student_history,
              history_type: :student_driven,
              assignment_book_container_uuids_map: assignment_student_book_container_uuids_map,
              course_excluded_uuids: course_excluded_uuids,
              random_ago: student_random_ago
            )

            assignment.spes_are_assigned = true
          end
        end

        # Record the AssignmentSpeCalculations
        null_bc_assignment_spe_calculations, bc_assignment_spe_calculations =
          assignment_spe_calculations.partition do |assignment_spe_calculation|
          assignment_spe_calculation.book_container_uuid.nil?
        end
        a_spe_calc_ids = AssignmentSpeCalculation.import(
          bc_assignment_spe_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [
              :assignment_uuid,
              :history_type,
              :k_ago,
              :book_container_uuid,
              :is_spaced
            ],
            columns: [ :exercise_uuids, :exercise_count ]
          }
        ).ids + AssignmentSpeCalculation.import(
          null_bc_assignment_spe_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [
              :assignment_uuid,
              :history_type,
              :k_ago,
              :is_spaced
            ],
            index_predicate: 'book_container_uuid IS NULL',
            columns: [ :exercise_uuids, :exercise_count ]
          }
        ).ids

        # Delete existing AlgorithmAssignmentSpeCalculations for affected AssignmentSpeCalculations,
        # since they need to be recalculated
        assignment_spe_calculation_uuids = AssignmentSpeCalculation.where(id: a_spe_calc_ids)
                                                                   .pluck(:uuid)
        AlgorithmAssignmentSpeCalculation
          .where(assignment_spe_calculation_uuid: assignment_spe_calculation_uuids)
          .delete_all

        assignment_spe_calculation_exercises = assignment_spe_calculations
                                                 .flat_map do |assignment_spe_calculation|
          assignment_spe_calculation.exercise_uuids.map do |exercise_uuid|
            AssignmentSpeCalculationExercise.new(
              uuid: SecureRandom.uuid,
              assignment_spe_calculation_uuid: assignment_spe_calculation.uuid,
              exercise_uuid: exercise_uuid,
              assignment_uuid: assignment_spe_calculation.assignment_uuid,
              student_uuid: assignment_spe_calculation.student_uuid
            )
          end
        end
        AssignmentSpeCalculationExercise.import(
          assignment_spe_calculation_exercises, validate: false, on_duplicate_key_ignore: {
            conflict_target: [ :assignment_spe_calculation_uuid, :exercise_uuid ]
          }
        )

        # Record the AssignmentPeCalculations
        a_pe_calc_ids = AssignmentPeCalculation.import(
          assignment_pe_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :assignment_uuid, :book_container_uuid ],
            columns: [ :exercise_uuids, :exercise_count ]
          }
        ).ids

        # Delete existing AlgorithmAssignmentPeCalculations for affected AssignmentPeCalculations,
        # since they need to be recalculated
        assignment_pe_calculation_uuids = AssignmentPeCalculation.where(id: a_pe_calc_ids)
                                                                 .pluck(:uuid)
        AlgorithmAssignmentPeCalculation
          .where(assignment_pe_calculation_uuid: assignment_pe_calculation_uuids)
          .delete_all

        assignment_pe_calculation_exercises = assignment_pe_calculations
                                                .flat_map do |assignment_pe_calculation|
          assignment_pe_calculation.exercise_uuids.map do |exercise_uuid|
            AssignmentPeCalculationExercise.new(
              uuid: SecureRandom.uuid,
              assignment_pe_calculation_uuid: assignment_pe_calculation.uuid,
              exercise_uuid: exercise_uuid,
              assignment_uuid: assignment_pe_calculation.assignment_uuid,
              student_uuid: assignment_pe_calculation.student_uuid
            )
          end
        end
        AssignmentPeCalculationExercise.import(
          assignment_pe_calculation_exercises, validate: false, on_duplicate_key_ignore: {
            conflict_target: [ :assignment_pe_calculation_uuid, :exercise_uuid ]
          }
        )

        # Record the fact that the calculations have been created
        Assignment.import(
          assignments, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ],
            columns: [ :spes_are_assigned, :pes_are_assigned ]
          }
        )

        assignments.size
      end

      # If we got less assignments than the batch size, then this is the last batch
      total_assignments += num_assignments
      break if num_assignments < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareAssignmentExerciseCalculations' do |logger|
      logger.debug do
        "#{total_assignments} assignment(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end

  protected

  def get_k_agos(random_ago = nil)
    [2, 4].tap do |k_agos|
      k_agos << random_ago unless random_ago.nil?
    end
  end

  def get_k_ago_map(assignment, assignment_sequence_number, history, random_ago = nil)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    k_agos = get_k_agos
    return [] if k_agos.empty?

    num_spes = assignment.goal_num_tutor_assigned_spes

    case num_spes
    when Integer
      # Tutor decides
      # Subtract 1 for random-ago if present
      num_spes -= 1 if random_ago.present?
      num_spes_per_k_ago, remainder = num_spes.divmod k_agos.size

      [].tap do |k_ago_map|
        k_agos.each_with_index do |k_ago, index|
          num_k_ago_spes = index < remainder ? num_spes_per_k_ago + 1 : num_spes_per_k_ago

          k_ago_map << [k_ago, num_k_ago_spes] if num_k_ago_spes > 0
        end

        # Add random-ago slot if present
        k_ago_map << [random_ago, 1] if random_ago.present?
      end
    when NilClass
      # Biglearn decides based on the history
      k_agos.map do |k_ago|
        # If not enough assignments for the k-ago, assign 1 per page in the current assignment
        # and use them as personalized exercises
        num_book_containers = ( history[assignment_sequence_number - k_ago]&.second ||
                                assignment.assigned_book_container_uuids ).size
        next if num_book_containers == 0

        [k_ago, num_book_containers * DEFAULT_NUM_SPES_PER_K_AGO_BOOK_CONTAINER]
      end.compact.tap do |k_ago_map|
        k_ago_map << [random_ago, 1] if random_ago.present?
      end
    else
      raise ArgumentError, "Invalid assignment num_spes: #{num_spes.inspect}", caller
    end
  end

  def get_exercise_uuids(assignment:, book_container_uuids:, course_excluded_uuids:)
    assignment_type = assignment.assignment_type
    student_uuid = assignment.student_uuid

    # Get exercises in relevant book containers for the relevant assignment type
    book_container_exercise_uuids = [book_container_uuids].flatten.flat_map do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type]
    end

    # Collect info about exercises that have already been assigned to this student
    times_assigned_by_exercise_group_uuid =
      @times_assigned_by_student_uuid_and_exercise_group_uuid[student_uuid]
    assigned_and_not_due_exercise_group_uuids =
      @assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid]

    # Remove duplicates (same assignment), exclusions and assigned and not yet due exercises
    allowed_exercise_uuids = ( book_container_exercise_uuids -
                               assignment.assigned_exercise_uuids -
                               course_excluded_uuids ).reject do |allowed_exercise_uuid|
      exercise_group_uuid = @exercise_group_uuid_by_uuid[allowed_exercise_uuid]
      assigned_and_not_due_exercise_group_uuids.include?(exercise_group_uuid)
    end

    # Shuffle then sort allowed exercises based on the number of times assigned
    # In the future we can replace this with explicitly returning the number of times assigned
    # and sending it to the algorithms
    allowed_exercise_uuids.shuffle.sort_by do |exercise_uuid|
      exercise_group_uuid = @exercise_group_uuid_by_uuid[exercise_uuid]
      times_assigned_by_exercise_group_uuid[exercise_group_uuid]
    end
  end

  def new_pe_calculations(assignment:, course_excluded_uuids:)
    assignment_type = assignment.assignment_type
    # Don't look at book containers with no dynamic exercises
    book_container_uuids = assignment.assigned_book_container_uuids.select do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type].any?
    end
    return [] if book_container_uuids.empty?

    assignment_uuid = assignment.uuid

    num_pes_per_book_container, remainder = assignment.goal_num_tutor_assigned_pes.nil? ?
      [DEFAULT_NUM_PES_PER_BOOK_CONTAINER, 0] :
      assignment.goal_num_tutor_assigned_pes.divmod(book_container_uuids.size)

    book_container_uuids.map do |book_container_uuid|
      book_container_num_pes = remainder > 0 ?
        num_pes_per_book_container + 1 : num_pes_per_book_container
      next if book_container_num_pes == 0

      candidate_personalized_exercise_uuids = get_exercise_uuids(
        assignment: assignment,
        book_container_uuids: book_container_uuid,
        course_excluded_uuids: course_excluded_uuids
      )

      num_candidate_pes = candidate_personalized_exercise_uuids.size
      num_assigned_pes = [book_container_num_pes, num_candidate_pes].min
      remainder += num_pes_per_book_container - num_assigned_pes

      AssignmentPeCalculation.new uuid: SecureRandom.uuid,
                                  ecosystem_uuid: assignment.ecosystem_uuid,
                                  assignment_uuid: assignment_uuid,
                                  book_container_uuid: book_container_uuid,
                                  student_uuid: assignment.student_uuid,
                                  exercise_uuids: candidate_personalized_exercise_uuids,
                                  exercise_count: num_assigned_pes
    end.compact
  end

  def new_spe_calculations(assignment:,
                           assignment_sequence_number:,
                           history:,
                           history_type:,
                           assignment_book_container_uuids_map:,
                           course_excluded_uuids:,
                           random_ago: nil)
    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type

    k_ago_map = get_k_ago_map(assignment, assignment_sequence_number, history, random_ago)

    k_ago_map.flat_map do |k_ago, num_exercises|
      # Don't look at book containers with no dynamic exercises
      book_container_uuids = assignment_book_container_uuids_map[k_ago]
                               .select do |book_container_uuid|
        @exercise_uuids_map[book_container_uuid][assignment_type].any?
      end

      num_book_containers = book_container_uuids.size
      if num_book_containers > 0
        # k-ago assignment exists
        num_spes_per_book_container, remainder = num_exercises.divmod(num_book_containers)

        book_container_uuids.flat_map do |book_container_uuid|
          book_container_num_spes = remainder > 0 ?
            num_spes_per_book_container + 1 : num_spes_per_book_container
          next [] if book_container_num_spes == 0

          candidate_spe_uuids = get_exercise_uuids(
            assignment: assignment,
            book_container_uuids: book_container_uuid,
            course_excluded_uuids: course_excluded_uuids
          )

          num_candidate_spes = candidate_spe_uuids.size
          num_assigned_spes = [book_container_num_spes, num_candidate_spes].min
          remainder += num_spes_per_book_container - num_assigned_spes

          # If not enough spaced practice exercises, fill up the rest with personalized ones
          book_container_num_pes = book_container_num_spes - num_assigned_spes
          if book_container_num_pes > 0
            candidate_pe_uuids = get_exercise_uuids(
              assignment: assignment,
              book_container_uuids: assignment.assigned_book_container_uuids,
              course_excluded_uuids: course_excluded_uuids
            )

            num_candidate_pes = candidate_pe_uuids.size
            num_assigned_pes = [book_container_num_pes, num_candidate_pes].min
            remainder -= num_assigned_pes
          else
            num_assigned_pes = 0
          end

          [].tap do |result|
            result << AssignmentSpeCalculation.new(
              uuid: SecureRandom.uuid,
              student_uuid: assignment.student_uuid,
              ecosystem_uuid: assignment.ecosystem_uuid,
              assignment_uuid: assignment_uuid,
              history_type: history_type,
              k_ago: k_ago,
              book_container_uuid: book_container_uuid,
              is_spaced: true,
              exercise_uuids: candidate_spe_uuids,
              exercise_count: num_assigned_spes
            ) if num_assigned_spes > 0

            # We still create AssignmentSpeCalculation for the PEs chosen
            # so they end up in the right slots
            # is_spaced: false denotes that they are actually PEs
            result << AssignmentSpeCalculation.new(
              uuid: SecureRandom.uuid,
              student_uuid: assignment.student_uuid,
              ecosystem_uuid: assignment.ecosystem_uuid,
              assignment_uuid: assignment_uuid,
              history_type: history_type,
              k_ago: k_ago,
              book_container_uuid: book_container_uuid,
              is_spaced: false,
              exercise_uuids: candidate_pe_uuids,
              exercise_count: num_assigned_pes
            ) if num_assigned_pes > 0
          end
        end
      else
        # k-ago assignment does not exist
        # Simply assign all needed exercises as personalized
        candidate_personalized_exercise_uuids = get_exercise_uuids(
          assignment: assignment,
          book_container_uuids: assignment.assigned_book_container_uuids,
          course_excluded_uuids: course_excluded_uuids
        )

        num_candidate_spes = candidate_personalized_exercise_uuids.size
        num_assigned_spes = [num_exercises, num_candidate_spes].min

        [
          AssignmentSpeCalculation.new(uuid: SecureRandom.uuid,
                                       student_uuid: assignment.student_uuid,
                                       ecosystem_uuid: assignment.ecosystem_uuid,
                                       assignment_uuid: assignment_uuid,
                                       history_type: history_type,
                                       k_ago: k_ago,
                                       book_container_uuid: nil,
                                       is_spaced: false,
                                       exercise_uuids: candidate_personalized_exercise_uuids,
                                       exercise_count: num_assigned_spes)
        ]
      end
    end
  end
end

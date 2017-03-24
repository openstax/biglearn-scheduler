class Services::UpdateAssignmentExercises::Service
  BATCH_SIZE = 1000

  DEFAULT_NUM_PES_PER_PAGE = 3
  DEFAULT_NUM_SPES_PER_K_AGO_PAGE = 1

  def process
    start_time = Time.now
    Rails.logger.tagged 'UpdateAssignmentExercises' do |logger|
      logger.info { "Started at #{start_time}" }
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
        student_random_ago_sequence_number_by_assignment_uuid = {}
        history_queries = assignments.map do |assignment|
          instructor_driven_sequence_number = assignment.instructor_driven_sequence_number
          student_driven_sequence_number = assignment.student_driven_sequence_number
          instructor_k_agos = get_k_agos
          instructor_sequence_number_queries = instructor_k_agos.map do |k_ago|
            aa[:instructor_driven_sequence_number].eq(instructor_driven_sequence_number - k_ago)
          end
          student_random_ago_sequence_number = rand(student_driven_sequence_number - 1) + 1 \
            if student_driven_sequence_number > instructor_k_agos.max
          student_random_ago_sequence_number_by_assignment_uuid[assignment.uuid] =
            student_random_ago_sequence_number
          student_sequence_number_queries = get_k_agos(student_random_ago_sequence_number)
                                              .map do |k_ago|
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
          student_random_ago_sequence_number =
            student_random_ago_sequence_number_by_assignment_uuid[assignment.uuid]
          student_spaced_assignments = get_k_agos(student_random_ago_sequence_number)
                                         .map do |k_ago|
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
          student_random_ago_sequence_number =
            student_random_ago_sequence_number_by_assignment_uuid[assignment_uuid]
          get_k_agos(student_random_ago_sequence_number).each do |k_ago|
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

        # Get any exercises that are already assigned as SPEs or PEs
        assignment_uuids = assignments.map(&:uuid)

        instructor_assigned_spe_uuids_map = Hash.new do |hash, key|
          hash[key] = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
        end
        AssignmentSpe.instructor_driven
                     .where(assignment_uuid: assignment_uuids)
                     .pluck(:assignment_uuid, :exercise_uuid, :k_ago, :book_container_uuid)
                     .each do |assignment_uuid, exercise_uuid, k_ago, book_container_uuid|
          instructor_assigned_spe_uuids_map[assignment_uuid][k_ago][book_container_uuid] <<
            exercise_uuid
        end

        student_assigned_spe_uuids_map = Hash.new do |hash, key|
          hash[key] = Hash.new do |hash, key|
            hash[key] = Hash.new { |hash, key| hash[key] = [] }
          end
        end
        AssignmentSpe.student_driven
                     .where(assignment_uuid: assignment_uuids)
                     .pluck(:assignment_uuid, :exercise_uuid, :k_ago, :book_container_uuid)
                     .each do |assignment_uuid, exercise_uuid, k_ago, book_container_uuid|
          student_assigned_spe_uuids_map[assignment_uuid][k_ago][book_container_uuid] <<
            exercise_uuid
        end

        assigned_pes_map = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        AssignmentPe.where(assignment_uuid: assignment_uuids)
                    .pluck(:assignment_uuid, :exercise_uuid, :book_container_uuid)
                    .each do |assignment_uuid, exercise_uuid, book_container_uuid|
          assigned_pes_map[assignment_uuid][book_container_uuid] << exercise_uuid
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
        assigned_exercise_uuids_by_student_uuid = Hash.new { |hash, key| hash[key] = [] }
        Assignment.where(student_uuid: student_uuids)
                  .pluck(:student_uuid, :assigned_exercise_uuids)
                  .each do |student_uuid, assigned_exercise_uuids|
          assigned_exercise_uuids_by_student_uuid[student_uuid].concat assigned_exercise_uuids
        end
        assigned_exercise_uuids = assigned_exercise_uuids_by_student_uuid.values.flatten

        # Convert relevant exercise uuids to group uuids
        relevant_exercise_uuids = @exercise_uuids_map.values.flat_map(&:values) +
                                  assigned_exercise_uuids
        @exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                               .pluck(:uuid, :group_uuid)
                                               .to_h

        # Convert map of already-assigned exercises to use group_uuid
        @assigned_exercise_group_uuids_by_student_uuid = {}
        assigned_exercise_uuids_by_student_uuid.each do |student_uuid, assigned_exercise_uuids|
          @assigned_exercise_group_uuids_by_student_uuid[student_uuid] = \
            @exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
        end

        # Assign Spaced Practice and Personalized exercises
        assignment_pes = []
        assignment_spes = []
        pe_updates = []
        spe_updates = []
        assignments.group_by(&:course_uuid).each do |course_uuid, assignments|
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]

          assignments.each do |assignment|
            assignment_uuid = assignment.uuid
            assignment_type = assignment.assignment_type
            student_uuid = assignment.student_uuid

            assigned_book_container_uuids = assignment.assigned_book_container_uuids

            assignment_instructor_assigned_spe_uuids_map = \
              instructor_assigned_spe_uuids_map[assignment_uuid]
            assignment_student_assigned_spe_uuids_map = \
              student_assigned_spe_uuids_map[assignment_uuid]
            assigned_spe_uuids = (
              assignment_instructor_assigned_spe_uuids_map.values +
              assignment_student_assigned_spe_uuids_map.values
            ).map(&:values).flatten.uniq
            assignment_assigned_pe_uuids_map = assigned_pes_map[assignment_uuid]
            assigned_pe_uuids = assignment_assigned_pe_uuids_map.values.flatten

            assignment_instructor_book_container_uuids_map = \
              instructor_book_container_uuids_map[assignment_uuid]
            assignment_student_book_container_uuids_map = \
              student_book_container_uuids_map[assignment_uuid]

            assignment_excluded_uuids = course_excluded_uuids +
                                        assigned_spe_uuids +
                                        assigned_pe_uuids

            instructor_history = instructor_histories[student_uuid][assignment_type]
            student_history = student_histories[student_uuid][assignment_type]

            # Personalized
            assign_pes(
              assignment: assignment,
              assignment_assigned_pe_uuids_map: assignment_assigned_pe_uuids_map,
              assignment_excluded_uuids: assignment_excluded_uuids,
              assignment_pes: assignment_pes,
              pe_updates: pe_updates
            )

            assignment.pes_are_assigned = true

            # Spaced Practice

            # Instructor-driven
            assign_spes(
              assignment: assignment,
              assignment_sequence_number: assignment.instructor_driven_sequence_number,
              history: instructor_history,
              history_type: :instructor_driven,
              assignment_assigned_spe_uuids_map: assignment_instructor_assigned_spe_uuids_map,
              assignment_book_container_uuids_map: assignment_instructor_book_container_uuids_map,
              assignment_excluded_uuids: assignment_excluded_uuids,
              assignment_spes: assignment_spes,
              spe_updates: spe_updates
            )

            # Student-driven
            student_random_ago_sequence_number =
              student_random_ago_sequence_number_by_assignment_uuid[assignment_uuid]
            assign_spes(
              assignment: assignment,
              assignment_sequence_number: assignment.student_driven_sequence_number,
              history: student_history,
              history_type: :student_driven,
              assignment_assigned_spe_uuids_map: assignment_student_assigned_spe_uuids_map,
              assignment_book_container_uuids_map: assignment_student_book_container_uuids_map,
              assignment_excluded_uuids: assignment_excluded_uuids,
              assignment_spes: assignment_spes,
              spe_updates: spe_updates,
              random_ago_sequence_number: student_random_ago_sequence_number
            )

            assignment.spes_are_assigned = true
          end
        end

        Assignment.import(
          assignments, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ],
            columns: [ :spes_are_assigned, :pes_are_assigned ]
          }
        )

        AssignmentSpe.import(
          assignment_spes, validate: false, on_duplicate_key_ignore: {
            conflict_target: [ :assignment_uuid, :history_type, :exercise_uuid ]
          }
        )

        AssignmentPe.import(
          assignment_pes, validate: false, on_duplicate_key_ignore: {
            conflict_target: [ :assignment_uuid, :exercise_uuid ]
          }
        )

        OpenStax::Biglearn::Api.update_assignment_spes spe_updates
        OpenStax::Biglearn::Api.update_assignment_pes  pe_updates

        assignments.size
      end

      # If we got less assignments than the batch size, then this is the last batch
      total_assignments += num_assignments
      break if num_assignments < BATCH_SIZE
    end

    Rails.logger.tagged 'UpdateAssignmentExercises' do |logger|
      logger.info do
        time = Time.now - start_time

        "Updated: #{total_assignments} assignment(s) - Took: #{time} second(s)"
      end
    end
  end

  protected

  def get_k_agos(random_ago_sequence_number = nil)
    [2, 4].tap do |k_agos|
      k_agos << random_ago_sequence_number unless random_ago_sequence_number.nil?
    end
  end

  def get_k_ago_map(assignment, assignment_sequence_number, history,
                    random_ago_sequence_number = nil)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    k_agos = get_k_agos
    return [] if k_agos.empty?

    num_spes = assignment.goal_num_tutor_assigned_spes

    case num_spes
    when Integer
      # Tutor decides
      # Subtract 1 for random-ago if present
      num_spes -= 1 if random_ago_sequence_number.present?
      num_spes_per_k_ago, remainder = num_spes.divmod k_agos.size

      [].tap do |k_ago_map|
        k_agos.each_with_index do |k_ago, index|
          num_k_ago_spes = index < remainder ? num_spes_per_k_ago + 1 : num_spes_per_k_ago

          k_ago_map << [k_ago, num_k_ago_spes] if num_k_ago_spes > 0
        end

        # Add random-ago slot if present
        k_ago_map << [random_ago_sequence_number, 1] if random_ago_sequence_number.present?
      end
    when NilClass
      # Biglearn decides based on the history
      k_agos.map do |k_ago|
        # If not enough assignments for the k-ago, assign 1 per page in the current assignment
        # and use them as personalized exercises
        spaced_assignment = history[assignment_sequence_number - k_ago] || assignment
        num_book_containers = spaced_assignment.assigned_book_container_uuids.size
        [k_ago, num_book_containers * DEFAULT_NUM_SPES_PER_K_AGO_PAGE] if num_book_containers > 0
      end.compact.tap do |k_ago_map|
        k_ago_map << [random_ago_sequence_number, 1] if random_ago_sequence_number.present?
      end
    else
      raise ArgumentError, "Invalid assignment num_spes: #{num_spes.inspect}", caller
    end
  end

  def get_exercise_uuids(assignment:, book_container_uuids:, excluded_uuids:, count:)
    return [] if count <= 0

    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type

    # Get exercises in relevant book containers for the relevant assignment type
    book_container_exercise_uuids = [book_container_uuids].flatten.flat_map do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type]
    end

    # Remove duplicates (same assignment - already assigned or already PEs/SPEs) and exclusions
    candidate_exercise_uuids = book_container_exercise_uuids -
                               assignment.assigned_exercise_uuids -
                               excluded_uuids

    # Partition remaining exercises into used and unused by group uuid
    student_uuid = assignment.student_uuid
    assigned_exercise_group_uuids = @assigned_exercise_group_uuids_by_student_uuid[student_uuid]
    assigned_candidate_exercise_uuids, unassigned_candidate_exercise_uuids = \
      candidate_exercise_uuids.partition do |exercise_uuid|
      group_uuid = @exercise_group_uuid_by_uuid[exercise_uuid]
      assigned_exercise_group_uuids.include?(group_uuid)
    end

    # Randomly pick candidate exercises, preferring unassigned ones
    unassigned_count = unassigned_candidate_exercise_uuids.size
    chosen_exercises = if count <= unassigned_count
      unassigned_candidate_exercise_uuids.sample(count)
    else
      ( unassigned_candidate_exercise_uuids +
        assigned_candidate_exercise_uuids.sample(count - unassigned_count) ).shuffle
    end
  end

  # NOTE: assignment_excluded_uuids, assignment_pes and pe_updates are all updated by this method
  def assign_pes(assignment:, assignment_assigned_pe_uuids_map:,
                 assignment_excluded_uuids:, assignment_pes:, pe_updates:)
    assignment_type = assignment.assignment_type
    # Don't look at book containers with no dynamic exercises
    book_container_uuids = assignment.assigned_book_container_uuids.select do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment_type].any?
    end
    return if book_container_uuids.empty?

    assignment_uuid = assignment.uuid

    num_pes_per_book_container, remainder = assignment.goal_num_tutor_assigned_pes.nil? ?
      [DEFAULT_NUM_PES_PER_BOOK_CONTAINER, 0] :
      assignment.goal_num_tutor_assigned_pes.divmod(book_container_uuids.size)

    personalized_exercise_uuids = book_container_uuids.flat_map do |book_container_uuid|
      book_container_num_pes = remainder > 0 ?
        num_pes_per_book_container + 1 : num_pes_per_book_container
      book_container_assigned_pe_uuids = assignment_assigned_pe_uuids_map[book_container_uuid]
      book_container_num_assigned_pes = book_container_assigned_pe_uuids.size
      num_pes_needed = book_container_num_pes - book_container_num_assigned_pes

      new_personalized_exercise_uuids = get_exercise_uuids(
        assignment: assignment,
        book_container_uuids: book_container_uuid,
        excluded_uuids: assignment_excluded_uuids,
        count: num_pes_needed
      )
      assignment_excluded_uuids.concat new_personalized_exercise_uuids

      new_assignment_pes = new_personalized_exercise_uuids.map do |pe_uuid|
        AssignmentPe.new uuid: SecureRandom.uuid,
                         assignment_uuid: assignment_uuid,
                         book_container_uuid: book_container_uuid,
                         student_uuid: assignment.student_uuid,
                         exercise_uuid: pe_uuid
      end
      assignment_pes.concat new_assignment_pes

      assigned_pe_uuids = book_container_assigned_pe_uuids + new_personalized_exercise_uuids

      remainder += num_pes_per_book_container - assigned_pe_uuids.size

      assigned_pe_uuids
    end

    pe_updates << {
      assignment_uuid: assignment_uuid,
      exercise_uuids: personalized_exercise_uuids
    }
  end

  # NOTE: assignment_spes and spe_updates are both updated by this method
  # assignment_excluded_uuids are NOT updated (externally) by this method
  # so we can call it twice in a row
  # This means SPEs must be populated AFTER PEs (or this method will need changes)
  def assign_spes(assignment:, assignment_sequence_number:, history:, history_type:,
                  assignment_assigned_spe_uuids_map:, assignment_book_container_uuids_map:,
                  assignment_excluded_uuids:, assignment_spes:, spe_updates:,
                  random_ago_sequence_number: nil)
    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type

    random_ago_sequence_number

    k_ago_map = get_k_ago_map(
      assignment, assignment_sequence_number, history, random_ago_sequence_number
    )
    current_assignment_excluded_uuids = assignment_excluded_uuids

    spaced_practice_exercise_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
      k_ago_assigned_spe_uuids_map = assignment_assigned_spe_uuids_map[k_ago]
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
          book_container_assigned_spe_uuids = k_ago_assigned_spe_uuids_map[book_container_uuid]
          book_container_num_assigned_spes = book_container_assigned_spe_uuids.size
          num_spes_needed = book_container_num_spes - book_container_num_assigned_spes

          new_spaced_exercise_uuids = get_exercise_uuids(
            assignment: assignment,
            book_container_uuids: book_container_uuid,
            excluded_uuids: current_assignment_excluded_uuids,
            count: num_spes_needed
          )
          current_assignment_excluded_uuids += new_spaced_exercise_uuids

          # If not enough spaced practice exercises, fill up the rest with personalized ones
          num_personalized_exercises_needed = num_spes_needed - new_spaced_exercise_uuids.size
          if num_personalized_exercises_needed > 0
            new_personalized_exercise_uuids = get_exercise_uuids(
              assignment: assignment,
              book_container_uuids: assignment.assigned_book_container_uuids,
              excluded_uuids: current_assignment_excluded_uuids,
              count: num_personalized_exercises_needed
            )
            current_assignment_excluded_uuids += new_personalized_exercise_uuids
          else
            new_personalized_exercise_uuids = []
          end

          new_exercise_uuids = new_spaced_exercise_uuids + new_personalized_exercise_uuids

          new_assignment_spes = new_exercise_uuids.map do |spe_uuid|
            AssignmentSpe.new uuid: SecureRandom.uuid,
                              student_uuid: assignment.student_uuid,
                              assignment_uuid: assignment_uuid,
                              history_type: history_type,
                              book_container_uuid: book_container_uuid,
                              exercise_uuid: spe_uuid,
                              k_ago: k_ago
          end
          assignment_spes.concat new_assignment_spes

          assigned_spe_uuids = book_container_assigned_spe_uuids + new_exercise_uuids

          remainder += num_spes_per_book_container - assigned_spe_uuids.size

          assigned_spe_uuids
        end
      else
        # k-ago assignment does not exist
        # Simply assign all needed exercises as personalized
        assigned_spe_uuids = k_ago_assigned_spe_uuids_map.values.flatten
        num_assigned_spes = assigned_spe_uuids.size
        num_personalized_exercises_needed = num_exercises - num_assigned_spes
        if num_personalized_exercises_needed > 0
          new_personalized_exercise_uuids = get_exercise_uuids(
            assignment: assignment,
            book_container_uuids: assignment.assigned_book_container_uuids,
            excluded_uuids: current_assignment_excluded_uuids,
            count: num_personalized_exercises_needed
          )
          current_assignment_excluded_uuids += new_personalized_exercise_uuids
        else
          new_personalized_exercise_uuids = []
        end

        new_assignment_spes = new_personalized_exercise_uuids.map do |spe_uuid|
          AssignmentSpe.new uuid: SecureRandom.uuid,
                            student_uuid: assignment.student_uuid,
                            assignment_uuid: assignment_uuid,
                            history_type: history_type,
                            book_container_uuid: nil,
                            exercise_uuid: spe_uuid,
                            k_ago: k_ago
        end
        assignment_spes.concat new_assignment_spes

        assigned_spe_uuids + new_personalized_exercise_uuids
      end
    end

    spe_updates << {
      assignment_uuid: assignment_uuid,
      algorithm_name: "local_query_#{history_type}",
      exercise_uuids: spaced_practice_exercise_uuids
    }
  end
end

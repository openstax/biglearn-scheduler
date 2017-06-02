class Services::UploadAssignmentExercises::Service < Services::ApplicationService
  BATCH_SIZE = 10

  DEFAULT_NUM_PES_PER_BOOK_CONTAINER = 3
  DEFAULT_NUM_SPES_PER_K_AGO = 1

  NON_RANDOM_K_AGOS = [ 1, 3 ]
  RANDOM_K_AGOS = [ 1, 2, 3, 4, 5 ]
  ALL_K_AGOS = (RANDOM_K_AGOS + NON_RANDOM_K_AGOS).uniq
  MAX_K_AGO = ALL_K_AGOS.max

  MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO = 5

  # NOTE: We don't support partial PE/SPE assignments, we create all of them in one go
  def process
    start_time = Time.now
    Rails.logger.tagged 'UploadAssignmentExercises' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    aa = Assignment.arel_table
    aspe = AssignmentSpe.arel_table
    ape = AssignmentPe.arel_table
    aec = AlgorithmExerciseCalculation.arel_table

    total_assignments = 0
    loop do
      num_assignments = Assignment.transaction do
        # Find assignments that need PEs or SPEs
        pe_assignments = Assignment
          .need_pes
          .select([
            aa[Arel.star],
            aec[:uuid].as('algorithm_exercise_calculation_uuid'),
            aec[:algorithm_name],
            aec[:exercise_uuids]
          ])
          .joins(exercise_calculation: :algorithm_exercise_calculations)
          .where(
            AssignmentPe.where(
              ape[:assignment_uuid].eq(aa[:uuid]).and(
                ape[:algorithm_exercise_calculation_uuid].eq aec[:uuid]
              )
            ).exists.not
          )
          .lock
          .take(BATCH_SIZE)

        spe_assignments = Assignment
          .need_spes
          .select([
            aa[Arel.star],
            aec[:uuid].as('algorithm_exercise_calculation_uuid'),
            aec[:algorithm_name],
            aec[:exercise_uuids]
          ])
          .joins(exercise_calculation: :algorithm_exercise_calculations)
          .where(
            AssignmentSpe.where(
              aspe[:assignment_uuid].eq(aa[:uuid]).and(
                aspe[:algorithm_exercise_calculation_uuid].eq aec[:uuid]
              )
            ).exists.not
          )
          .lock
          .take(BATCH_SIZE)

        assignments = (pe_assignments + spe_assignments).uniq

        # TODO: Combine .with_instructor_and_student_driven_sequence_numbers queries into 1
        spe_student_uuids = spe_assignments.map(&:student_uuid)
        spe_assignment_types = spe_assignments.map(&:assignment_type)
        spe_assignment_uuids = spe_assignments.map(&:uuid)
        instructor_sequence_numbers_by_assignment_uuid = {}
        student_sequence_numbers_by_assignment_uuid = {}
        Assignment
          .with_instructor_and_student_driven_sequence_numbers(
            student_uuids: spe_student_uuids, assignment_types: spe_assignment_types
          )
          .where(uuid: spe_assignment_uuids)
          .pluck(:uuid, :instructor_driven_sequence_number, :student_driven_sequence_number)
          .each do |uuid, instructor_driven_sequence_number, student_driven_sequence_number|
          instructor_sequence_numbers_by_assignment_uuid[uuid] = instructor_driven_sequence_number
          student_sequence_numbers_by_assignment_uuid[uuid] = student_driven_sequence_number
        end

        # Build assignment histories so we can find SPE book_container_uuids
        history_queries = spe_assignments.map do |spe_assignment|
          uuid = spe_assignment.uuid
          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          instructor_k_agos = NON_RANDOM_K_AGOS
          instructor_sequence_number_queries = instructor_k_agos.map do |k_ago|
            aa[:instructor_driven_sequence_number].eq(instructor_sequence_number - k_ago)
          end

          # Find the range of allowed k's for student SPEs
          student_sequence_number_query =
            aa[:student_driven_sequence_number].gteq(student_sequence_number - MAX_K_AGO).and(
              aa[:student_driven_sequence_number].lteq(student_sequence_number)
            )

          sequence_number_query = (
            instructor_sequence_number_queries + [ student_sequence_number_query ]
          ).reduce(:or)

          aa[:student_uuid].eq(spe_assignment.student_uuid).and(
            aa[:assignment_type].eq(spe_assignment.assignment_type).and(sequence_number_query)
          ) unless sequence_number_query.nil?
        end.compact.reduce(:or)
        instructor_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        student_histories = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = {} }
        end
        Assignment.with_instructor_and_student_driven_sequence_numbers(
          student_uuids: spe_student_uuids, assignment_types: spe_assignment_types
        ).where(history_queries)
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
        mapping_queries = spe_assignments.map do |spe_assignment|
          uuid = spe_assignment.uuid
          student_uuid = spe_assignment.student_uuid
          assignment_type = spe_assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          to_ecosystem_uuid = spe_assignment.ecosystem_uuid

          instructor_spaced_assignments = NON_RANDOM_K_AGOS.map do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
            instructor_history[instructor_spaced_sequence_number]
          end.compact
          student_spaced_assignments = ALL_K_AGOS.map do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
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

          NON_RANDOM_K_AGOS.flat_map do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
            instructor_from_ecosystem_uuid, instructor_spaced_book_container_uuids = \
              instructor_history[instructor_spaced_sequence_number]
            instructor_spaced_book_container_uuids ||= []

            if instructor_from_ecosystem_uuid == to_ecosystem_uuid
              instructor_spaced_book_container_uuids
            else
              instructor_spaced_book_container_uuids.map do |book_container_uuid|
                ecosystems_map[to_ecosystem_uuid][book_container_uuid]
              end
            end
          end + ALL_K_AGOS.flat_map do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
            student_from_ecosystem_uuid, student_spaced_book_container_uuids = \
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
            @exercise_uuids_map[book_container_uuid][assignment_type].concat exercise_uuids
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

        # Get assignments that are not yet due for each student
        student_uuids = assignments.map(&:student_uuid)
        not_yet_due_assignments = Assignment
                                    .where(student_uuid: student_uuids)
                                    .where(aa[:due_at].gt(start_time))
                                    .pluck(:uuid, :student_uuid, :due_at, :assigned_exercise_uuids)

        # Convert not yet due exercise uuids to group uuids
        assigned_exercise_uuids = not_yet_due_assignments.flat_map(&:fourth)
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

        # Add the exclusions from not yet due assignments to the map above
        not_yet_due_assignments.each do |uuid, student_uuid, due_at, assigned_exercise_uuids|
          excluded_group_uuids =
            assigned_exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
          excluded_exercise_uuids =
            excluded_exercise_uuids_by_group_uuid.values_at(*excluded_group_uuids).flatten
          excluded_uuids_by_student_uuid[student_uuid].concat excluded_exercise_uuids
        end

        # Remove book containers that have no exercises after all exclusions from the histories
        instructor_histories.each do |student_uuid, student_instructor_histories|
          excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          student_instructor_histories
            .each do |assignment_type, student_assignment_type_instructor_histories|
            student_assignment_type_instructor_histories.each do |sequence_number, history_entry|
              history_entry.second.reject! do |book_container_uuid|
                ( @exercise_uuids_map[book_container_uuid][assignment_type] -
                  excluded_exercise_uuids ).empty?
              end
            end
          end
        end
        student_histories.each do |student_uuid, student_student_histories|
          excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          student_student_histories
            .each do |assignment_type, student_assignment_type_student_histories|
            student_assignment_type_student_histories.each do |sequence_number, history_entry|
              history_entry.second.reject! do |book_container_uuid|
                ( @exercise_uuids_map[book_container_uuid][assignment_type] -
                  excluded_exercise_uuids ).empty?
              end
            end
          end
        end

        # Map book_container_uuids with exercises to the current ecosystem spaced assignments
        instructor_book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        student_book_container_uuids_map = Hash.new { |hash, key| hash[key] = {} }
        spe_assignments.each do |spe_assignment|
          uuid = spe_assignment.uuid
          student_uuid = spe_assignment.student_uuid
          assignment_type = spe_assignment.assignment_type
          instructor_history = instructor_histories[student_uuid][assignment_type]
          student_history = student_histories[student_uuid][assignment_type]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)
          to_ecosystem_uuid = spe_assignment.ecosystem_uuid

          NON_RANDOM_K_AGOS.each do |k_ago|
            instructor_spaced_sequence_number = instructor_sequence_number - k_ago
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

            instructor_book_container_uuids_map[uuid][k_ago] = instructor_mapped_book_containers
          end
          ALL_K_AGOS.each do |k_ago|
            student_spaced_sequence_number = student_sequence_number - k_ago
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

            student_book_container_uuids_map[uuid][k_ago] = student_mapped_book_containers
          end
        end

        # Personalized
        assignment_pes = []
        assignment_pe_requests = []
        pe_assignments.each do |assignment|
          prioritized_exercise_uuids = assignment.exercise_uuids
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]

          new_pes = new_pes(
            assignment: assignment,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
            excluded_exercise_uuids: student_excluded_exercise_uuids
          )
          assignment_pes.concat new_pes
          assignment_pe_requests << {
            assignment_uuid: assignment.uuid,
            exercise_uuids: new_pes.map(&:exercise_uuid).compact,
            algorithm_name: assignment.algorithm_name
          }
        end

        # Send the AssignmentPes to the api server and record them
        OpenStax::Biglearn::Api.update_assignment_pes(assignment_pe_requests) \
          if assignment_pe_requests.any?

        AssignmentPe.import assignment_pes, validate: false

        # Remove SPEs for any assignments that are using the PEs above (PEs have priority over SPEs)
        unless assignment_pe_requests.empty?
          aspe_query = assignment_pe_requests.map do |assignment_pe_request|
            aspe[:assignment_uuid].eq(assignment_pe_request[:assignment_uuid]).and(
              aspe[:exercise_uuid].in(assignment_pe_request[:exercise_uuids])
            )
          end.reduce(:or)
          conflicting_assignment_uuids = AssignmentSpe.where(aspe_query).pluck(:assignment_uuid)
          AssignmentSpe.where(assignment_uuid: conflicting_assignment_uuids).delete_all
        end

        excluded_pe_uuids_by_assignment_uuid = Hash.new { |hash, key| hash[key] = [] }
        AssignmentPe
          .where(assignment_uuid: spe_assignment_uuids)
          .where.not(exercise_uuid: nil)
          .pluck(:assignment_uuid, :exercise_uuid)
          .each do |assignment_uuid, exercise_uuid|
          excluded_pe_uuids_by_assignment_uuid[assignment_uuid] << exercise_uuid
        end

        # Spaced Practice
        assignment_spes = []
        assignment_spe_requests = []
        spe_assignments.each do |assignment|
          uuid = assignment.uuid
          assignment_type = assignment.assignment_type
          student_uuid = assignment.student_uuid
          algorithm_name = assignment.algorithm_name
          prioritized_exercise_uuids = assignment.exercise_uuids
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          assigned_book_container_uuids = assignment.assigned_book_container_uuids

          assignment_instructor_book_container_uuids_map = \
            instructor_book_container_uuids_map[uuid]
          assignment_student_book_container_uuids_map = \
            student_book_container_uuids_map[uuid]

          instructor_sequence_number = instructor_sequence_numbers_by_assignment_uuid.fetch(uuid)
          student_sequence_number = student_sequence_numbers_by_assignment_uuid.fetch(uuid)

          excluded_exercise_uuids = student_excluded_exercise_uuids +
                                    excluded_pe_uuids_by_assignment_uuid[uuid]

          # Instructor-driven
          new_instructor_driven_spes = new_spes(
            assignment: assignment,
            assignment_sequence_number: instructor_sequence_number,
            history_type: :instructor_driven,
            assignment_book_container_uuids_map: assignment_instructor_book_container_uuids_map,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
            excluded_exercise_uuids: excluded_exercise_uuids
          )
          assignment_spes.concat new_instructor_driven_spes
          assignment_spe_requests << {
            assignment_uuid: uuid,
            exercise_uuids: new_instructor_driven_spes.map(&:exercise_uuid).compact,
            algorithm_name: "instructor_driven_#{algorithm_name}"
          }

          # Student-driven
          new_student_driven_spes = new_spes(
            assignment: assignment,
            assignment_sequence_number: student_sequence_number,
            history_type: :student_driven,
            assignment_book_container_uuids_map: assignment_student_book_container_uuids_map,
            prioritized_exercise_uuids: prioritized_exercise_uuids,
            excluded_exercise_uuids: excluded_exercise_uuids
          )
          assignment_spes.concat new_student_driven_spes
          assignment_spe_requests << {
            assignment_uuid: uuid,
            exercise_uuids: new_student_driven_spes.map(&:exercise_uuid).compact,
            algorithm_name: "student_driven_#{algorithm_name}"
          }
        end

        # Send the AssignmentSpes to the api server and record them
        OpenStax::Biglearn::Api.update_assignment_spes(assignment_spe_requests) \
          if assignment_spe_requests.any?

        AssignmentSpe.import assignment_spes, validate: false

        assignments.size
      end

      # If we got less assignments than the batch size, then this is the last batch
      total_assignments += num_assignments
      break if num_assignments < BATCH_SIZE
    end

    Rails.logger.tagged 'UploadAssignmentExercises' do |logger|
      logger.debug do
        "#{total_assignments} assignment(s) processed in #{Time.now - start_time} second(s)"
      end
    end
  end

  protected

  def get_k_ago_map(assignment, assignment_sequence_number, include_random_ago = false)
    # Entries in the list have the form:
    # [from-this-many-assignments-ago, pick-this-many-exercises]
    num_spes = assignment.goal_num_tutor_assigned_spes

    case num_spes
    when Integer
      # Tutor decides
      # Subtract 1 for random-ago
      num_spes -= 1 if include_random_ago
      num_spes_per_k_ago, remainder = num_spes.divmod NON_RANDOM_K_AGOS.size

      [].tap do |k_ago_map|
        NON_RANDOM_K_AGOS.each_with_index do |k_ago, index|
          num_k_ago_spes = index < remainder ? num_spes_per_k_ago + 1 : num_spes_per_k_ago

          k_ago_map << [k_ago, num_k_ago_spes] if num_k_ago_spes > 0
        end

        k_ago_map << [nil, 1] if include_random_ago
      end
    when NilClass
      # Biglearn decides
      NON_RANDOM_K_AGOS.map do |k_ago|
        [k_ago, DEFAULT_NUM_SPES_PER_K_AGO]
      end.compact.tap do |k_ago_map|
        k_ago_map << [nil, 1] if include_random_ago
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
    book_container_exercise_uuids = book_container_uuids.flat_map do |book_container_uuid|
      @exercise_uuids_map[book_container_uuid][assignment.assignment_type]
    end

    # Remove duplicates (same assignment), exclusions and assigned and not yet due exercises
    allowed_exercise_uuids = book_container_exercise_uuids -
                             assignment.assigned_exercise_uuids -
                             excluded_exercise_uuids

    (prioritized_exercise_uuids & allowed_exercise_uuids).first(exercise_count)
  end

  def new_pes(assignment:, prioritized_exercise_uuids:, excluded_exercise_uuids:)
    assignment_type = assignment.assignment_type
    assignment_excluded_uuids = excluded_exercise_uuids
    # Ignore book containers with no dynamic exercises
    book_container_uuids = assignment.assigned_book_container_uuids
                                     .uniq
                                     .reject do |book_container_uuid|
      ( @exercise_uuids_map[book_container_uuid][assignment_type] -
        assignment_excluded_uuids ).empty?
    end.shuffle
    return [] if book_container_uuids.empty?

    assignment_uuid = assignment.uuid
    algorithm_exercise_calculation_uuid = assignment.algorithm_exercise_calculation_uuid

    num_pes_per_book_container, remainder = assignment.goal_num_tutor_assigned_pes.nil? ?
      [DEFAULT_NUM_PES_PER_BOOK_CONTAINER, 0] :
      assignment.goal_num_tutor_assigned_pes.divmod(book_container_uuids.size)

    book_container_uuids.flat_map do |book_container_uuid|
      book_container_num_pes = remainder > 0 ?
        num_pes_per_book_container + 1 : num_pes_per_book_container
      next [] if book_container_num_pes == 0

      chosen_pe_uuids = choose_exercise_uuids(
        assignment: assignment,
        book_container_uuids: book_container_uuid,
        prioritized_exercise_uuids: prioritized_exercise_uuids,
        excluded_exercise_uuids: assignment_excluded_uuids,
        exercise_count: book_container_num_pes
      )

      num_chosen_pes = chosen_pe_uuids.size
      remainder += num_pes_per_book_container - num_chosen_pes
      assignment_excluded_uuids += chosen_pe_uuids

      chosen_pe_uuids.map do |chosen_pe_uuid|
        AssignmentPe.new(
          uuid: SecureRandom.uuid,
          algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
          assignment_uuid: assignment_uuid,
          exercise_uuid: chosen_pe_uuid
        )
      end
    end.tap do |result|
      # If no PEs, record an AssignmentPe with nil exercise_uuid
      # to denote that we already processed this assignment
      result << AssignmentPe.new(
        uuid: SecureRandom.uuid,
        algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
        assignment_uuid: assignment_uuid,
        exercise_uuid: nil
      ) if result.empty?
    end
  end

  def new_spes(assignment:,
               assignment_sequence_number:,
               history_type:,
               assignment_book_container_uuids_map:,
               prioritized_exercise_uuids:,
               excluded_exercise_uuids:)
    assignment_uuid = assignment.uuid
    assignment_type = assignment.assignment_type
    algorithm_exercise_calculation_uuid = assignment.algorithm_exercise_calculation_uuid

    include_random_ago = history_type == :student_driven &&
                         assignment_sequence_number >= MIN_SEQUENCE_NUMBER_FOR_RANDOM_AGO
    k_ago_map = get_k_ago_map(assignment, assignment_sequence_number, include_random_ago)

    assignment_excluded_uuids = excluded_exercise_uuids

    forbidden_random_k_agos = k_ago_map.map(&:first).compact
    allowed_random_k_agos = RANDOM_K_AGOS - forbidden_random_k_agos
    num_remaining_exercises = 0
    chosen_spe_uuids = k_ago_map.flat_map do |k_ago, num_exercises|
      num_remaining_exercises += num_exercises

      book_container_uuids = (
        k_ago.nil? ?
          assignment_book_container_uuids_map.values_at(*allowed_random_k_agos).compact.flatten :
          assignment_book_container_uuids_map[k_ago]
      ).uniq#.shuffle # TODO: Shuffle causes intermittent failure... see question in #tutor-biglearn
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

    (chosen_spe_uuids + chosen_pe_uuids).map do |chosen_exercise_uuid|
      AssignmentSpe.new(
        uuid: SecureRandom.uuid,
        algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
        assignment_uuid: assignment_uuid,
        history_type: history_type,
        exercise_uuid: chosen_exercise_uuid
      )
    end.tap do |result|
      # If no SPEs, record an AssignmentSpe with nil exercise_uuid
      # to denote that we already processed this assignment
      result << AssignmentSpe.new(
        uuid: SecureRandom.uuid,
        algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
        assignment_uuid: assignment_uuid,
        history_type: history_type,
        exercise_uuid: nil
      ) if result.empty?
    end
  end
end

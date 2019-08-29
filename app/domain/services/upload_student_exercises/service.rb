class Services::UploadStudentExercises::Service < Services::ApplicationService
  BATCH_SIZE = 10

  NUM_PES_PER_STUDENT = 5
  MAX_NUM_WORST_CLUES = NUM_PES_PER_STUDENT

  def process
    start_time = Time.current
    log(:debug) { "Started at #{start_time}" }

    st = Student.arel_table
    aec = AlgorithmExerciseCalculation.arel_table
    ec = ExerciseCalculation.arel_table
    cc = Course.arel_table
    ascc = AlgorithmStudentClueCalculation.arel_table
    aa = Assignment.arel_table

    total_algorithm_exercise_calculations = 0
    loop do
      num_algorithm_exercise_calculations = AlgorithmExerciseCalculation.transaction do
        # Find algorithm_exercise_calculations with students that need PEs
        # No order needed because of SKIP LOCKED
        algorithm_exercise_calculations = AlgorithmExerciseCalculation
          .select([:uuid, :algorithm_name, :exercise_uuids])
          .where(is_pending_for_student: true)
          .lock('FOR NO KEY UPDATE SKIP LOCKED')
          .take(BATCH_SIZE)
        algorithm_exercise_calculations_size = algorithm_exercise_calculations.size
        next 0 if algorithm_exercise_calculations_size == 0

        algorithm_exercise_calculations_by_uuid = algorithm_exercise_calculations.index_by(&:uuid)
        algorithm_exercise_calculation_uuids = algorithm_exercise_calculations_by_uuid.keys

        # Don't bother updating calculations for old ecosystems
        students = Student
          .select([ st[Arel.star], aec[:uuid].as('algorithm_exercise_calculation_uuid') ])
          .joins(:course, exercise_calculations: :algorithm_exercise_calculations)
          .where(algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids })
          .where(ec[:ecosystem_uuid].eq(cc[:ecosystem_uuid]))
        student_uuids = students.map(&:uuid)

        # Delete all StudentPes for the above calculations
        StudentPe.joins(:algorithm_exercise_calculation).where(
          algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids }
        ).ordered_delete_all

        # Get the worst clues for each student
        worst_clues_by_student_uuid_and_algorithm_name = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        AlgorithmStudentClueCalculation
          .with_student_clue_calculation_attributes_and_partitioned_rank(
            student_uuids: student_uuids
          )
          .where(ascc[:partitioned_rank].lteq(MAX_NUM_WORST_CLUES))
          .order(:partitioned_rank)
          .each do |algorithm_student_clue_calculation|
          student_uuid = algorithm_student_clue_calculation.student_uuid
          algorithm_name = algorithm_student_clue_calculation.algorithm_name

          worst_clues_by_student_uuid_and_algorithm_name[student_uuid][algorithm_name] <<
            algorithm_student_clue_calculation
        end

        # Get all practice exercises in the relevant book containers
        relevant_book_container_uuids = worst_clues_by_student_uuid_and_algorithm_name
          .values.flat_map do |worst_clues_by_algorithm_name|
          worst_clues_by_algorithm_name.values.flat_map do |worst_clues|
            worst_clues.map(&:book_container_uuid)
          end
        end
        exercise_uuids_by_book_container_uuids = Hash.new { |hash, key| hash[key] = [] }
        ExercisePool.where(
          book_container_uuid: relevant_book_container_uuids
        ).pluck(
          :book_container_uuid, :use_for_personalized_for_assignment_types, :exercise_uuids
        ).each do |book_container_uuid, assignment_types, exercise_uuids|
          next unless assignment_types.include? 'practice'

          exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
        end

        # Get exercise exclusions for each course
        course_uuids = students.map(&:course_uuid)
        course_exclusions_by_course_uuid = Course.where(uuid: course_uuids).pluck(
          :uuid,
          :global_excluded_exercise_uuids,
          :course_excluded_exercise_uuids,
          :global_excluded_exercise_group_uuids,
          :course_excluded_exercise_group_uuids
        ).index_by(&:first)

        # Get assignments that should have hidden feedback for each student
        no_feedback_yet_assignments = Assignment
                                        .where(student_uuid: student_uuids)
                                        .where(aa[:feedback_at].gt(start_time))
                                        .pluck(:student_uuid, :assigned_exercise_uuids)

        # Convert not yet due exercise uuids to group uuids
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
        students.group_by(&:course_uuid).each do |course_uuid, students|
          course_exclusions = course_exclusions_by_course_uuid[course_uuid]
          next if course_exclusions.nil?

          group_uuids = course_exclusions.fourth + course_exclusions.fifth
          converted_excluded_exercise_uuids =
            excluded_exercise_uuids_by_group_uuid.values_at(*group_uuids).flatten
          course_excluded_uuids = course_exclusions.second +
                                  course_exclusions.third +
                                  converted_excluded_exercise_uuids

          students.each do |student|
            excluded_uuids_by_student_uuid[student.uuid].concat course_excluded_uuids
          end
        end

        # Add the exclusions from not yet due assignments to the map above
        no_feedback_yet_assignments.each do |student_uuid, assigned_exercise_uuids|
          excluded_group_uuids =
            assigned_exercise_group_uuid_by_uuid.values_at(*assigned_exercise_uuids)
          excluded_exercise_uuids =
            excluded_exercise_uuids_by_group_uuid.values_at(*excluded_group_uuids).flatten
          excluded_uuids_by_student_uuid[student_uuid].concat excluded_exercise_uuids
        end

        student_pe_requests = []
        student_pes = []
        students.each do |student|
          student_uuid = student.uuid
          algorithm_exercise_calculation_uuid = student.algorithm_exercise_calculation_uuid
          algorithm_exercise_calculation = algorithm_exercise_calculations_by_uuid
                                             .fetch(algorithm_exercise_calculation_uuid)
          prioritized_exercise_uuids = algorithm_exercise_calculation.exercise_uuids
          student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[student_uuid]

          worst_clues_by_algorithm_name =
            worst_clues_by_student_uuid_and_algorithm_name[student_uuid]

          exercise_algorithm_name = algorithm_exercise_calculation.algorithm_name
          clue_algorithm_name = StudentPe.exercise_to_clue_algorithm_name(exercise_algorithm_name)

          worst_clues = worst_clues_by_algorithm_name[clue_algorithm_name] || []

          # Create a map of chosen exercises for each worst CLUe
          candidate_pe_uuids = worst_clues.map do |clue|
            # Get practice exercises in the CLUe's book container
            book_container_uuid = clue.book_container_uuid
            book_container_exercise_uuids = \
              exercise_uuids_by_book_container_uuids[book_container_uuid]

            # Remove exclusions and assigned and not yet due exercises
            allowed_pe_uuids = book_container_exercise_uuids - student_excluded_exercise_uuids

            (prioritized_exercise_uuids & allowed_pe_uuids).first(NUM_PES_PER_STUDENT)
          end

          num_worst_clues = worst_clues.size
          worst_clue_num_pes_map = get_worst_clue_num_pes_map(num_worst_clues)

          # Assign the candidate exercises for each position in the worst_clue_pes_map
          # based on the priority of each CLUe
          chosen_pe_uuids = []
          worst_clues.each_with_index do |clue, index|
            clue_num_pes = worst_clue_num_pes_map[index] || 0

            next [] if clue_num_pes == 0 # No slot is available for this CLUe

            # Prioritize the candidate exercises for this slot
            prioritized_candidate_pe_uuids = (
              [ candidate_pe_uuids[index] ] +
              candidate_pe_uuids.first(index) +
              candidate_pe_uuids.last(num_worst_clues - index - 1)
            ).flatten.uniq - chosen_pe_uuids

            new_chosen_pe_uuids = prioritized_candidate_pe_uuids.first(clue_num_pes)

            chosen_pe_uuids.concat new_chosen_pe_uuids
          end

          student_pe_request = {
            student_uuid: student_uuid,
            exercise_uuids: chosen_pe_uuids,
            algorithm_name: exercise_algorithm_name,
            spy_info: {
              clue_algorithm_name: clue_algorithm_name,
              exercise_algorithm_name: exercise_algorithm_name
            }
          }
          student_pe_requests << student_pe_request

          exercise_uuids = student_pe_request[:exercise_uuids]
          pes = exercise_uuids.map do |exercise_uuid|
            StudentPe.new(
              uuid: SecureRandom.uuid,
              algorithm_exercise_calculation_uuid: algorithm_exercise_calculation_uuid,
              exercise_uuid: exercise_uuid
            )
          end
          student_pes.concat pes
        end

        # Send the StudentPes to the api server and record them
        OpenStax::Biglearn::Api.update_practice_worst_areas(student_pe_requests) \
          if student_pe_requests.any?

        # No sort needed because no conflict clause
        StudentPe.import student_pes, validate: false

        # Mark the AlgorithmExerciseCalculations as uploaded
        # No order needed because already locked above
        AlgorithmExerciseCalculation.where(uuid: algorithm_exercise_calculation_uuids)
                                    .update_all(is_pending_for_student: false)

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

  protected

  def get_worst_clue_num_pes_map(num_clues)
    case num_clues
    when 0
      []
    when 1
      [5]
    when 2
      [3, 2]
    when 3
      [2, 2, 1]
    when 4
      [2, 1, 1, 1]
    else
      # 5 is the current maximum
      [1, 1, 1, 1, 1]
    end
  end
end

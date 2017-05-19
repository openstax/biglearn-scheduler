class Services::PrepareStudentExerciseCalculations::Service < Services::ApplicationService
  BATCH_SIZE = 1000

  MAX_NUM_WORST_CLUES = 5

  def process
    start_time = Time.now
    Rails.logger.tagged 'PrepareStudentExerciseCalculations' do |logger|
      logger.debug { "Started at #{start_time}" }
    end

    total_students = 0
    loop do
      num_students = Student.transaction do
        # Process only students whose worst clue clue_values or book_container_uuids changed
        students = Student.where(pes_are_assigned: false).take(BATCH_SIZE)
        student_uuids = students.map(&:uuid)

        # Get the worst clues for each student
        worst_clues_by_student_uuid_and_algorithm_name = Hash.new do |hash, key|
          hash[key] = Hash.new { |hash, key| hash[key] = [] }
        end
        AlgorithmStudentClueCalculation
          .with_student_clue_calculation_attributes_and_partitioned_rank(
            student_uuids: student_uuids
          )
          .where("partitioned_rank <= #{MAX_NUM_WORST_CLUES}")
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
        ExercisePool.where(book_container_uuid: relevant_book_container_uuids).pluck(
          :book_container_uuid,
          :use_for_personalized_for_assignment_types,
          :exercise_uuids
        ).each do |book_container_uuid, assignment_types, exercise_uuids|
          next unless assignment_types.include? 'practice'

          exercise_uuids_by_book_container_uuids[book_container_uuid].concat exercise_uuids
        end

        # Get exercise exclusions for each course
        course_uuids = students.map(&:course_uuid)
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
        relevant_exercise_uuids = ( exercise_uuids_by_book_container_uuids.values +
                                    student_assignments.map(&:fourth) ).flatten
        exercise_group_uuid_by_uuid = Exercise.where(uuid: relevant_exercise_uuids)
                                              .pluck(:uuid, :group_uuid)
                                              .to_h

        # Convert the maps above to use exercise_group_uuids
        times_assigned_by_student_uuid_and_exercise_group_uuid = Hash.new do |hash, key|
          hash[key] = Hash.new(0)
        end
        assigned_and_not_due_exercise_group_uuids_by_student_uuid = Hash.new do |hash, key|
          hash[key] = []
        end
        times_assigned_by_student_uuid_and_exercise_uuid
          .each do |student_uuid, times_assigned_by_exercise_uuid|
          times_assigned_by_exercise_uuid.each do |exercise_uuid, times_assigned|
            group_uuid = exercise_group_uuid_by_uuid[exercise_uuid]
            times_assigned_by_student_uuid_and_exercise_group_uuid[student_uuid][group_uuid] +=
              times_assigned
          end
        end
        assigned_and_not_due_exercise_uuids_by_student_uuid
          .each do |student_uuid, assigned_and_not_due_exercise_uuids|
          assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid] =
            exercise_group_uuid_by_uuid.values_at(*assigned_and_not_due_exercise_uuids).unique
        end

        # Create PE calculations to be sent to the algorithms
        student_pe_calculations = students.flat_map do |student|
          student_uuid = student.uuid
          course_uuid = student.course_uuid
          course_excluded_uuids = excluded_uuids_by_course_uuid[course_uuid]

          # Collect info about exercises that have already been assigned to this student
          times_assigned_by_exercise_group_uuid =
            times_assigned_by_student_uuid_and_exercise_group_uuid[student_uuid]
          assigned_and_not_due_exercise_group_uuids =
            assigned_and_not_due_exercise_group_uuids_by_student_uuid[student_uuid]

          student.pes_are_assigned = true

          worst_clues_by_algorithm_name =
            worst_clues_by_student_uuid_and_algorithm_name[student_uuid]
          worst_clues_by_algorithm_name.flat_map do |algorithm_name, worst_clues|
            # Create a map of candidate exercises for each worst CLUe
            candidate_exercise_uuids = worst_clues.map do |clue|
              # Get practice exercises in the CLUe's book container
              book_container_uuid = clue.book_container_uuid
              book_container_exercise_uuids = \
                exercise_uuids_by_book_container_uuids[book_container_uuid]

              # Remove exclusions and assigned and not yet due exercises
              allowed_exercise_uuids = ( book_container_exercise_uuids -
                                         course_excluded_uuids ).reject do |allowed_exercise_uuid|
                exercise_group_uuid = exercise_group_uuid_by_uuid[allowed_exercise_uuid]
                assigned_and_not_due_exercise_group_uuids.include?(exercise_group_uuid)
              end

              # Shuffle then sort allowed exercises based on the number of times assigned
              # In the future we can replace this with explicitly returning the number of times
              # assigned and sending it to the algorithms
              allowed_exercise_uuids.shuffle.sort_by do |exercise_uuid|
                exercise_group_uuid = exercise_group_uuid_by_uuid[exercise_uuid]
                times_assigned_by_exercise_group_uuid[exercise_group_uuid]
              end
            end

            num_worst_clues = worst_clues.size
            worst_clue_num_pes_map = get_worst_clue_num_pes_map(num_worst_clues)

            # Assign the candidate exercises for each position in the worst_clue_pes_map
            # based on the priority of each CLUe
            worst_clues.each_with_index.map do |clue, index|
              clue_num_pes = worst_clue_num_pes_map[index] || 0

              next if clue_num_pes == 0

              # Prioritize the CLUes for filling this slot based on the book containers
              prioritized_candidate_exercise_uuids = \
                [ candidate_exercise_uuids[index] ] +
                candidate_exercise_uuids.first(index) +
                candidate_exercise_uuids.last(num_worst_clues - index - 1)

              remaining_num_pes = clue_num_pes
              candidate_personalized_exercise_uuids = []
              prioritized_candidate_exercise_uuids.each do |candidate_exercise_uuids|
                candidate_personalized_exercise_uuids.concat candidate_exercise_uuids

                remaining_num_pes -= candidate_exercise_uuids.size

                break if remaining_num_pes <= 0
              end

              num_candidate_pes = candidate_personalized_exercise_uuids.size
              num_assigned_pes = [clue_num_pes, num_candidate_pes].min

              StudentPeCalculation.new uuid: SecureRandom.uuid,
                                       clue_algorithm_name: algorithm_name,
                                       ecosystem_uuid: clue.ecosystem_uuid,
                                       book_container_uuid: clue.book_container_uuid,
                                       student_uuid: student.uuid,
                                       exercise_uuids: candidate_personalized_exercise_uuids,
                                       exercise_count: num_assigned_pes
            end.compact
          end
        end

        # Record the StudentPeCalculations
        s_pe_calc_ids = StudentPeCalculation.import(
          student_pe_calculations, validate: false, on_duplicate_key_update: {
            conflict_target: [ :student_uuid, :book_container_uuid, :clue_algorithm_name ],
            columns: [ :exercise_uuids, :exercise_count ]
          }
        ).ids

        # Delete existing AlgorithmStudentPeCalculations for affected StudentPeCalculations,
        # since they need to be recalculated
        student_pe_calculation_uuids = StudentPeCalculation.where(id: s_pe_calc_ids)
                                                           .pluck(:uuid)
        AlgorithmStudentPeCalculation
          .where(student_pe_calculation_uuid: student_pe_calculation_uuids)
          .delete_all

        student_pe_calculation_exercises = student_pe_calculations
                                             .flat_map do |student_pe_calculation|
          student_pe_calculation.exercise_uuids.map do |exercise_uuid|
            StudentPeCalculationExercise.new(
              uuid: SecureRandom.uuid,
              student_pe_calculation: student_pe_calculation,
              exercise_uuid: exercise_uuid
            )
          end
        end
        StudentPeCalculationExercise.import(
          student_pe_calculation_exercises, validate: false, on_duplicate_key_ignore: {
            conflict_target: [ :student_pe_calculation_uuid, :exercise_uuid ]
          }
        )

        Student.import(
          students, validate: false, on_duplicate_key_update: {
            conflict_target: [ :uuid ], columns: [ :pes_are_assigned ]
          }
        )

        students.size
      end

      # If we got less students than the batch size, then this is the last batch
      total_students += num_students
      break if num_students < BATCH_SIZE
    end

    Rails.logger.tagged 'PrepareStudentExerciseCalculations' do |logger|
      logger.debug do
        "#{total_students} student(s) updated in #{Time.now - start_time} second(s)"
      end
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
      # 5 is the max
      [1, 1, 1, 1, 1]
    end
  end
end

class CreateUpdateAssignmentSideEffectsJob < ApplicationJob
  include AssignmentExerciseRequests

  def perform_with_transaction(
    assignment_uuids:,
    assigned_exercise_uuids:,
    algorithm_exercise_calculation_uuids:
  )
    # Find relevant ExerciseCalculations
    # The ExerciseCalculation lock ensures we don't miss updates on
    # concurrent AlgorithmExerciseCalculation inserts
    assignment = Assignment.arel_table
    assigned_ex_ex_uuid = AssignedExercise.arel_table[:exercise_uuid]
    student_pe_ex_uuid = StudentPe.arel_table[:exercise_uuid]
    assignment_pe_ex_uuid = AssignmentPe.arel_table[:exercise_uuid]
    assignment_spe_ex_uuid = AssignmentSpe.arel_table[:exercise_uuid]
    ec = ExerciseCalculation.arel_table
    assignment_uuids_by_exercise_calculation_uuid = {}
    ExerciseCalculation.select(:uuid, '"ec"."assignment_uuid"').joins(
      <<~JOIN_SQL
        INNER JOIN (
          #{
            ExerciseCalculation
              .select(:uuid, assignment[:uuid].as('assignment_uuid'))
              .joins(:assignments)
              .not_superseded
              .where(assignments: { uuid: assignment_uuids })
              .merge(Assignment.need_pes_or_spes)
              .to_sql
          }
          UNION ALL
          #{
            ExerciseCalculation
              .select(:uuid, 'NULL as "assignment_uuid"')
              .joins(
                algorithm_exercise_calculations: :student_pes,
                student: { assignments: :assigned_exercises }
              )
              .not_superseded
              .where(assigned_ex_ex_uuid.eq(student_pe_ex_uuid))
              .where(assigned_exercises: { uuid: assigned_exercise_uuids })
              .to_sql
          }
          UNION ALL
          #{
            ExerciseCalculation
              .select(:uuid, assignment[:uuid].as('assignment_uuid'))
              .joins(assignments: :assignment_pes, student: { assignments: :assigned_exercises })
              .not_superseded
              .merge(Assignment.need_pes_or_spes)
              .where(assigned_ex_ex_uuid.eq(assignment_pe_ex_uuid))
              .where(assigned_exercises: { uuid: assigned_exercise_uuids })
              .to_sql
          }
          UNION ALL
          #{
            ExerciseCalculation
              .select(:uuid, assignment[:uuid].as('assignment_uuid'))
              .joins(assignments: :assignment_spes, student: { assignments: :assigned_exercises })
              .not_superseded
              .merge(Assignment.need_pes_or_spes)
              .where(assigned_ex_ex_uuid.eq(assignment_spe_ex_uuid))
              .where(assigned_exercises: { uuid: assigned_exercise_uuids })
              .to_sql
          }
          UNION ALL
          #{
            ExerciseCalculation
              .select(:uuid, 'NULL as "assignment_uuid"')
              .joins(:algorithm_exercise_calculations)
              .where(
                algorithm_exercise_calculations: { uuid: algorithm_exercise_calculation_uuids }
              )
              .to_sql
          }
        ) AS "ec" ON "exercise_calculations".uuid = "ec"."uuid"
      JOIN_SQL
    )
    .ordered
    .lock('FOR NO KEY UPDATE OF "exercise_calculations"')
    .pluck(:uuid, :assignment_uuid)
    .each do |exercise_calculation_uuid, assignment_uuid|
      # Make sure the exercise_calculation_uuid exists in the hash, even if it is empty
      assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid] ||= []
      next if assignment_uuid.nil?

      assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid] << assignment_uuid
    end

    used_exercise_calculations_uuids = []
    algorithm_exercise_calculation_values = []
    AlgorithmExerciseCalculation
      .where(exercise_calculation_uuid: assignment_uuids_by_exercise_calculation_uuid.keys)
      .ordered
      .lock('FOR NO KEY UPDATE')
      .pluck(:uuid, :exercise_calculation_uuid, :pending_assignment_uuids)
      .each do |uuid, exercise_calculation_uuid, pending_assignment_uuids|
      used_exercise_calculations_uuids << exercise_calculation_uuid \
        if algorithm_exercise_calculation_uuids.include? uuid

      a_uuids = assignment_uuids_by_exercise_calculation_uuid[exercise_calculation_uuid]
      # Don't bother updating records where assignment_uuids is empty
      algorithm_exercise_calculation_values << [
        uuid, (pending_assignment_uuids + a_uuids).uniq
      ] unless a_uuids.empty?
    end

    ExerciseCalculation.where(uuid: used_exercise_calculations_uuids)
                       .ordered_update_all(is_used_in_assignments: true) \
      unless used_exercise_calculations_uuids.empty?

    unless algorithm_exercise_calculation_values.empty?
      AlgorithmExerciseCalculation.update_all(
        <<~UPDATE_SQL
          "pending_assignment_uuids" = "values"."pending_assignment_uuids"
          FROM (#{ValuesTable.new(algorithm_exercise_calculation_values)}) AS "values"
            ("uuid", "pending_assignment_uuids")
          WHERE "algorithm_exercise_calculations"."uuid" = "values"."uuid"::uuid
        UPDATE_SQL
      )
    end

    # Anti-cheating: we don't allow StudentPes that have already been assigned elsewhere
    # Recalculate Student PEs that conflict with the AssignedExercises that were just created
    AlgorithmExerciseCalculation
      .joins(
        :student_pes, exercise_calculation: { student: { assignments: :assigned_exercises } }
      )
      .where('"assigned_exercises"."exercise_uuid" = "student_pes"."exercise_uuid"')
      .where(assigned_exercises: { uuid: assigned_exercise_uuids })
      .ordered_update_all(is_pending_for_student: true) \
        unless assigned_exercise_uuids.empty?

    # Get assignments that need PEs or SPEs and do not yet have an ExerciseCalculation
    default_assignments = Assignment.need_pes_or_spes.joins(
      :default_exercise_calculation
    ).where(uuid: assignment_uuids).where(
      AlgorithmExerciseCalculation.where(
        AlgorithmExerciseCalculation.arel_table[:exercise_calculation_uuid].eq(ec[:uuid])
      ).arel.exists
    ).where.not(
      ExerciseCalculation.where(
        ec[:student_uuid].eq(assignment[:student_uuid]),
        ec[:ecosystem_uuid].eq(assignment[:ecosystem_uuid])
      ).arel.exists
    ).preload(default_exercise_calculation: :algorithm_exercise_calculations).to_a

    exercise_uuids_map = get_exercise_uuids_map(
      default_assignments.map(&:assigned_book_container_uuids).uniq
    )

    excluded_uuids_by_student_uuid = get_excluded_exercises_by_student_uuid default_assignments

    # Upload default assignment PE information
    default_pe_reqs = default_assignments.select(&:needs_pes?).flat_map do |assignment|
      exercise_calculation = assignment.default_exercise_calculation
      student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]

      exercise_calculation.algorithm_exercise_calculations.map do |algorithm_exercise_calculation|
        build_pe_request(
          algorithm_exercise_calculation: algorithm_exercise_calculation,
          assignment: assignment,
          exercise_uuids_map: exercise_uuids_map,
          excluded_exercise_uuids: student_excluded_exercise_uuids
        )
      end
    end

    # Send the default AssignmentPEs to the API server
    OpenStax::Biglearn::Api.update_assignment_pes(default_pe_reqs) if default_pe_reqs.any?

    # Upload default assignment SPE information
    default_spe_reqs = default_assignments.select(&:needs_spes?).flat_map do |assignment|
      exercise_calculation = assignment.default_exercise_calculation
      student_excluded_exercise_uuids = excluded_uuids_by_student_uuid[assignment.student_uuid]

      exercise_calculation.algorithm_exercise_calculations.flat_map do |aec|
        [ :student_driven, :instructor_driven ].map do |history_type|
          build_spe_request(
            algorithm_exercise_calculation: aec,
            assignment: assignment,
            assignment_sequence_number: 0,
            history_type: history_type,
            assignment_history: {
              0 => {
                assignment_uuid: assignment.uuid,
                book_container_uuids: assignment.assigned_book_container_uuids
              }
            },
            exercise_uuids_map: exercise_uuids_map,
            excluded_exercise_uuids: student_excluded_exercise_uuids
          )
        end
      end
    end

    # Send the default AssignmentSPEs to the API server
    OpenStax::Biglearn::Api.update_assignment_spes(default_spe_reqs) if default_spe_reqs.any?
  end
end

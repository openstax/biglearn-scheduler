class Services::FetchExerciseCalculations::Service < Services::ApplicationService
  def process(algorithm_name:)
    apec = AssignmentPeCalculation.arel_table
    aapec = AlgorithmAssignmentPeCalculation.arel_table
    apec_query = apec[:uuid].eq(aapec[:assignment_pe_calculation_uuid]).and(
      aapec[:algorithm_name].eq(algorithm_name)
    )
    apec_join = "LEFT OUTER JOIN algorithm_assignment_pe_calculations ON #{apec_query.to_sql}"
    assignment_pe_calculations = AssignmentPeCalculation
                                   .joins(apec_join)
                                   .where(algorithm_assignment_pe_calculations: {id: nil})
                                   .limit(1000)

    aspec = AssignmentSpeCalculation.arel_table
    aaspec = AlgorithmAssignmentSpeCalculation.arel_table
    aspec_query = aspec[:uuid].eq(aaspec[:assignment_spe_calculation_uuid]).and(
      aaspec[:algorithm_name].eq(algorithm_name)
    )
    aspec_join = "LEFT OUTER JOIN algorithm_assignment_spe_calculations ON #{aspec_query.to_sql}"
    assignment_spe_calculations = AssignmentSpeCalculation
                                    .joins(aspec_join)
                                    .where(algorithm_assignment_spe_calculations: {id: nil})
                                    .limit(1000)

    spec = StudentPeCalculation.arel_table
    aspec = AlgorithmStudentPeCalculation.arel_table
    spec_query = spec[:uuid].eq(aspec[:student_pe_calculation_uuid]).and(
      aspec[:algorithm_name].eq(algorithm_name)
    )
    spec_join = "LEFT OUTER JOIN algorithm_student_pe_calculations ON #{spec_query.to_sql}"
    student_pe_calculations = StudentPeCalculation
                                .joins(spec_join)
                                .where(algorithm_student_pe_calculations: {id: nil})
                                .limit(1000)

    exercise_calculations = assignment_pe_calculations +
                            assignment_spe_calculations +
                            student_pe_calculations
    exercise_calculation_responses = exercise_calculations.map do |exercise_calculation|
      {
        calculation_uuid: exercise_calculation.uuid,
        ecosystem_uuid: exercise_calculation.ecosystem_uuid,
        student_uuid: exercise_calculation.student_uuid,
        exercise_uuids: exercise_calculation.exercise_uuids
      }
    end

    { exercise_calculations: exercise_calculation_responses }
  end
end

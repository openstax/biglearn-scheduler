class UpdateCourseEcosystemSideEffectsJob < ApplicationJob
  def perform_with_transaction(course_uuids:)
    # Get students in courses with updated ecosystems
    student_uuids = Student.where(course_uuid: course_uuids).pluck(:uuid)

    # Mark student CLUes for recalculation for students in courses with updated ecosystems
    StudentClueCalculation.where(student_uuid: student_uuids)
                          .ordered_update_all(recalculate_at: Time.current)
  end
end

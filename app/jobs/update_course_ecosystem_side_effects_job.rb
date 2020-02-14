class UpdateCourseEcosystemSideEffectsJob < ApplicationJob
  def perform(course_uuids_with_changed_ecosystems:)
    # Get students in courses with updated ecosystems
    changed_student_uuids = Student
      .where(course_uuid: course_uuids_with_changed_ecosystems)
      .pluck(:uuid)

    # Mark student CLUes for recalculation for students in courses with updated ecosystems
    StudentClueCalculation.where(student_uuid: changed_student_uuids)
                          .ordered_update_all(recalculate_at: Time.current)
  end
end

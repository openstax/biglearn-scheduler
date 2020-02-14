class UpdateRosterSideEffectsJob < ApplicationJob
  def perform(course_uuids:)
    # Get course containers in courses with updated rosters
    course_container_uuids = CourseContainer.where(course_uuid: course_uuids).pluck(:uuid)

    # Mark teacher CLUes for recalculation for course containers in courses with updated rosters
    TeacherClueCalculation.where(course_container_uuid: course_container_uuids)
                          .ordered_update_all(recalculate_at: Time.current)
  end
end

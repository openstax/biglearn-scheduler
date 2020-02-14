class UpdateRosterSideEffectsJob < ApplicationJob
  def perform(course_uuids_with_changed_rosters:)
    # Get course containers in courses with updated rosters
    changed_course_container_uuids = CourseContainer
      .where(course_uuid: course_uuids_with_changed_rosters)
      .pluck(:uuid)

    # Mark teacher CLUes for recalculation for course containers in courses with updated rosters
    TeacherClueCalculation.where(course_container_uuid: changed_course_container_uuids)
                          .ordered_update_all(recalculate_at: Time.current)
  end
end

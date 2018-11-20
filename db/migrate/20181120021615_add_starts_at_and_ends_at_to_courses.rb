class AddStartsAtAndEndsAtToCourses < ActiveRecord::Migration[5.0]
  def change
    add_column :courses, :starts_at, :datetime
    add_column :courses, :ends_at, :datetime

    reversible do |dir|
      dir.up do
        Course.reset_column_information

        Services::FetchCourseEvents::Service.process event_types: [ :update_course_active_dates ],
                                                     restart: true
      end
    end

    add_index :courses, [ :ends_at, :starts_at ]
  end
end

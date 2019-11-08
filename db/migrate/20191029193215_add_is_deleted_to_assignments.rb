class AddIsDeletedToAssignments < ActiveRecord::Migration[5.2]
  def change
    add_column :assignments, :is_deleted, :boolean

    reversible do |dir|
      dir.up do
        Services::FetchCourseEvents::Service.process(
          event_types: [ :create_update_assignment ], restart: true
        )

        change_column_null :assignments, :is_deleted, false, false
      end
    end
  end
end

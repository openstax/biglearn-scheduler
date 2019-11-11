class AddIsDeletedToAssignments < ActiveRecord::Migration[5.2]
  def change
    add_column :assignments, :is_deleted, :boolean

    reversible do |dir|
      dir.up do
        change_column_null :assignments, :is_deleted, false, false

        # A simple background migration with the drawback that it will not retry errors
        background_migration = -> do
          # Become a daemon so the calling process can exit successfully
          Process.daemon

          Services::FetchCourseEvents::Service.process(
            event_types: [ :create_update_assignment ], restart: true
          )
        end

        # This code will run after all foreground migrations have finished
        at_exit { background_migration.call }
      end
    end
  end
end

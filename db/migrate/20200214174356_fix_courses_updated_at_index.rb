class FixCoursesUpdatedAtIndex < ActiveRecord::Migration[5.2]
  def change
    remove_index :courses, column: :updated_at, where: '"ends_at" IS NULL AND "starts_at" IS NULL'
    add_index :courses, :updated_at
  end
end

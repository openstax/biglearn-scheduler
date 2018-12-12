class AddStartsAtAndEndsAtToCourses < ActiveRecord::Migration[5.0]
  def change
    add_column :courses, :starts_at, :datetime
    add_column :courses, :ends_at, :datetime
    add_index :courses, [ :ends_at, :starts_at ]
  end
end

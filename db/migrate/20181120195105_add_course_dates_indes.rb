class AddCourseDatesIndes < ActiveRecord::Migration[5.0]
  def change
    add_index :courses, :updated_at, where: '"ends_at" IS NULL AND "starts_at" IS NULL'
  end
end

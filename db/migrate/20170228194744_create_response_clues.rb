class CreateResponseClues < ActiveRecord::Migration[5.0]
  def change
    create_table :response_clues do |t|
      t.uuid :uuid,        null: false, index: { unique: true }
      t.uuid :course_uuid, null: false, index: true

      t.timestamps         null: false
    end
  end
end

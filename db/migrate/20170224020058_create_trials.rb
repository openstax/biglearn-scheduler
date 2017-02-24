class CreateTrials < ActiveRecord::Migration
  def change
    create_table :trials do |t|
      t.uuid :uuid,           null: false, index: { unique: true }
      t.uuid :ecosystem_uuid, null: false, index: true

      t.timestamps            null: false
    end
  end
end

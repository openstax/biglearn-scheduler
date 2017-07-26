class CreateExerciseGroups < ActiveRecord::Migration[5.0]
  BATCH_SIZE = 1000

  def change
    create_table :exercise_groups do |t|
      t.uuid    :uuid,           null: false, index: { unique: true }
      t.integer :response_count, null: false

      t.timestamps               null: false
    end

    reversible do |dir|
      dir.up do
        ex = Exercise.arel_table
        last_group_uuid = nil

        loop do
          num_groups = Exercise.transaction do
            ex_rel = Exercise.distinct.order(:group_uuid).limit(BATCH_SIZE)
            ex_rel = ex_rel.where(ex[:group_uuid].gt(last_group_uuid)) unless last_group_uuid.nil?
            group_uuids = ex_rel.pluck(:group_uuid)
            last_uuid = group_uuids.last

            exercise_groups = group_uuids.map do |group_uuid|
              ExerciseGroup.new(uuid: group_uuid, response_count: 0)
            end

            ExerciseGroup.import exercise_groups, validate: false

            group_uuids.size
          end

          break if num_groups < BATCH_SIZE
        end
      end
    end
  end
end

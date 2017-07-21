class ResetCourseAndEcosystemIdSequences < ActiveRecord::Migration[5.0]
  def up
    # This relies on the fact that find_each orders the records by id
    Course.find_each.each_with_index do |course, index|
      course.update_attribute(:id, index + 1) unless course.id == index + 1
    end
    Course.connection.execute 'SELECT setval(\'courses_id_seq\', max(id)) FROM courses;'

    Ecosystem.find_each.each_with_index do |ecosystem, index|
      ecosystem.update_attribute(:id, index + 1) unless ecosystem.id == index + 1
    end
    Ecosystem.connection.execute 'SELECT setval(\'ecosystems_id_seq\', max(id)) FROM ecosystems;'
  end

  def down
  end
end

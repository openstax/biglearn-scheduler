class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  validates :uuid, presence: true, uniqueness: true

  # The columns listed here should make up a unique index that exists on the record's table
  def self.unique_index(*columns)
    raise ArgumentError if columns.size == 0

    scope :ordered, -> { order(*columns) }
    define_singleton_method :sort_proc do
      ->(model) { columns.map { |column| model.public_send column } }
    end

    # Deadlock-resistant update_all and delete_all
    define_singleton_method :ordered_update_all do |*args|
      unscoped.where(uuid: ordered.lock('FOR NO KEY UPDATE').pluck(:uuid)).update_all(*args)
    end
    define_singleton_method :ordered_delete_all do |*args|
      unscoped.where(uuid: ordered.lock.pluck(:uuid)).delete_all(*args)
    end

    last_column = columns.last

    other_columns = columns[0..-2]
    other_columns.each { |column| validates column, presence: true }

    return if last_column == :uuid

    uniqueness_args = other_columns.empty? ? true : { scope: other_columns }
    validates last_column, presence: true, uniqueness: uniqueness_args
  end
end

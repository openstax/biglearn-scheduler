class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  validates :uuid, presence: true, uniqueness: true

  def self.sanitize(sql)
    connection.quote sql
  end

  def self.recursive_hash_to_array(hash)
    hash.respond_to?(:map) ? hash.map { |val| recursive_hash_to_array(val) } : hash
  end

  # The columns listed here should make up a unique index that exists on the record's table
  def self.unique_index(*columns)
    raise ArgumentError if columns.size == 0

    class_attribute :order_columns
    self.order_columns = columns

    scope :ordered, -> { order(*order_columns) }

    # Not quite random order, but gives us 1 of 4 possible orderings, which should reduce collisions
    scope :random_ordered, -> do
      rel = rand < 0.5 ? ordered : order(:id)
      rand < 0.5 ? rel : rel.reverse_order
    end

    define_singleton_method :sort_proc do
      ->(model) { order_columns.map { |column| model.public_send column } }
    end

    # Deadlock-resistant update_all and delete_all
    define_singleton_method :ordered_update_all do |*pargs, lock_sql: nil, **kwargs|
      lock_sql ||= "FOR NO KEY UPDATE OF #{table_name}"
      uuids = ordered.lock(lock_sql).pluck(:uuid)
      next 0 if uuids.empty?

      args = kwargs.empty? ? pargs : pargs + [kwargs]
      unscoped.where(uuid: uuids).update_all(*args)
    end
    define_singleton_method :ordered_delete_all do |*pargs, lock_sql: nil, **kwargs|
      lock_sql ||= "FOR UPDATE OF #{table_name}"
      uuids = ordered.lock(lock_sql).pluck(:uuid)
      next 0 if uuids.empty?

      args = kwargs.empty? ? pargs : pargs + [kwargs]
      unscoped.where(uuid: uuids).delete_all(*args)
    end

    last_column = order_columns.last

    other_columns = order_columns[0..-2]
    other_columns.each { |column| validates column, presence: true }

    return if last_column == :uuid

    uniqueness_args = other_columns.empty? ? true : { scope: other_columns }
    validates last_column, presence: true, uniqueness: uniqueness_args
  end
end

# https://github.com/rails/rails/issues/32374#issuecomment-378122738
module ActiveRecord
  class TableMetadata
    def associated_table(table_name)
      association = klass._reflect_on_association(table_name) || klass._reflect_on_association(table_name.to_s.singularize)

      if !association && table_name == arel_table.name
        return self
      elsif association && !association.polymorphic?
        association_klass = association.klass
        arel_table = association_klass.arel_table
      else
        type_caster = TypeCaster::Connection.new(klass, table_name)
        association_klass = nil
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
      end

      TableMetadata.new(association_klass, arel_table, association)
    end
  end
end

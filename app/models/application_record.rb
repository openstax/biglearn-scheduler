class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  validates :uuid, presence: true, uniqueness: true

  def self.recursive_hash_to_array(hash)
    hash.respond_to?(:map) ? hash.map { |val| recursive_hash_to_array(val) } : hash
  end

  # The columns listed here should make up a unique index that exists on the record's table
  def self.unique_index(*columns, scoped_to: nil)
    raise ArgumentError if columns.size == 0

    class_attribute :order_columns
    self.order_columns = columns

    scope_reflection = reflect_on_association(scoped_to) unless scoped_to.nil?

    scope :ordered, -> do
      rel = all

      if scope_reflection
        joins = recursive_hash_to_array(rel.joins_values).flatten
        rel = rel.left_outer_joins(scoped_to) unless joins.include?(scoped_to.to_sym)

        scoped_to_table_name = scope_reflection.table_name.to_sym
        scope_columns = scope_reflection.klass.order_columns.map do |column|
          "\"#{scoped_to_table_name}\".\"#{column}\""
        end
        rel = rel.order(*scope_columns)
      end

      rel.order(*order_columns)
    end
    define_singleton_method :sort_proc do
      ->(model) do
        scope_order = []

        if scope_reflection
          scope = model.public_send(scoped_to)

          scope_order = scope.class.sort_proc.call(scope) unless scope.nil?
        end

        scope_order + order_columns.map { |column| model.public_send column }
      end
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

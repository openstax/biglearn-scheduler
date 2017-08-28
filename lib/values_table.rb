class ValuesTable
  UUID_REGEX = /\A[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\z/i

  attr_reader :values_array

  def initialize(values_array)
    @values_array = values_array
  end

  def to_sql
    "VALUES #{values_array.map do |values|
      "(#{values.map { |value| sanitize value }.join(', ')})"
    end.join(', ')}"
  end

  def to_s
    to_sql
  end

  protected

  def sanitize(value)
    return "ARRAY[#{value.map { |val| sanitize val }}]" if value.is_a?(Array)

    sanitized_value = ActiveRecord::Base.sanitize value

    UUID_REGEX === value ? "#{sanitized_value}::uuid" : sanitized_value
  end
end
